# -*- coding: utf-8 -*-
"""
云智 ERP · REST v1 服务
仅使用 Python 标准库，Windows / macOS / Linux 均可运行。
接口契约与 iOS 工程 Core/Network.swift 的 APIRoutes 一一对应。
"""
import base64
import json
import logging
import os
import sys
import threading
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

APP_DIR = Path(__file__).resolve().parent
ROOT = APP_DIR.parent
sys.path.insert(0, str(APP_DIR))
import seed  # noqa: E402
import auth  # noqa: E402

VERSION = "0.1.0"

API_DOCS = [
    {"group": "认证", "method": "POST", "path": "/v1/auth/login", "desc": "用户名密码登录，返回会话 Token"},
    {"group": "认证", "method": "GET", "path": "/v1/auth/me", "desc": "当前登录用户"},
    {"group": "认证", "method": "POST", "path": "/v1/auth/logout", "desc": "退出登录"},
    {"group": "认证", "method": "POST", "path": "/v1/auth/password", "desc": "修改密码（需原密码）"},
    {"group": "认证", "method": "GET", "path": "/v1/auth/users", "desc": "账号列表（管理员）"},
    {"group": "认证", "method": "POST", "path": "/v1/auth/users", "desc": "新建账号（管理员）"},
    {"group": "工作台", "method": "GET", "path": "/v1/dashboard/summary", "desc": "KPI、待办、最近订单、销售趋势、异常提醒"},
    {"group": "销售", "method": "GET", "path": "/v1/sales-orders", "desc": "订单列表，支持 ?q= &status="},
    {"group": "销售", "method": "GET", "path": "/v1/sales-orders/{id}", "desc": "订单详情"},
    {"group": "销售", "method": "POST", "path": "/v1/sales-orders", "desc": "新建销售订单"},
    {"group": "销售", "method": "PATCH", "path": "/v1/sales-orders/{id}/status", "desc": "变更状态 {\"status\":\"已确认\"}"},
    {"group": "采购", "method": "GET", "path": "/v1/purchase-orders", "desc": "采购单列表"},
    {"group": "采购", "method": "GET", "path": "/v1/purchase-orders/{id}", "desc": "采购单详情"},
    {"group": "采购", "method": "PATCH", "path": "/v1/purchase-orders/{id}/status", "desc": "变更采购状态"},
    {"group": "库存", "method": "GET", "path": "/v1/inventory/items", "desc": "库存列表，支持 ?q= &low_stock=true"},
    {"group": "库存", "method": "GET", "path": "/v1/inventory/movements", "desc": "出入库流水"},
    {"group": "库存", "method": "GET", "path": "/v1/inventory/outbound/search", "desc": "仓储出库查找：?q= &warehouse= &date_from= &date_to= &operator= &sku= &type="},
    {"group": "库存", "method": "POST", "path": "/v1/inventory/outbound", "desc": "登记出库 {sku,quantity,warehouse?,receiver?,note?,date?}"},
    {"group": "库存", "method": "POST", "path": "/v1/inventory/items/{id}/adjust", "desc": "调整库存 {\"delta\":10}"},
    {"group": "库存", "method": "POST", "path": "/v1/inventory/inbound", "desc": "拍照入库（可带 base64 照片）"},
    {"group": "生产", "method": "GET", "path": "/v1/work-orders", "desc": "工单列表"},
    {"group": "生产", "method": "PATCH", "path": "/v1/work-orders/{id}/progress", "desc": "报工 {\"doneQty\":300}"},
    {"group": "财务", "method": "GET", "path": "/v1/invoices", "desc": "往来单据，支持 ?type= &status="},
    {"group": "财务", "method": "POST", "path": "/v1/invoices/{id}/settle", "desc": "登记结算 {\"amount\":1000}"},
    {"group": "基础资料", "method": "GET", "path": "/v1/master/customers", "desc": "客户列表"},
    {"group": "基础资料", "method": "GET", "path": "/v1/master/suppliers", "desc": "供应商列表"},
    {"group": "基础资料", "method": "GET", "path": "/v1/master/products", "desc": "商品列表"},
    {"group": "报表", "method": "GET", "path": "/v1/reports/overview", "desc": "销售/采购趋势、品类与仓库占比"},
    {"group": "运维", "method": "GET", "path": "/health", "desc": "健康检查"},
    {"group": "运维", "method": "GET", "path": "/v1/meta", "desc": "接口清单"},
    {"group": "运维", "method": "POST", "path": "/v1/admin/reset", "desc": "重置演示数据"},
]


def load_config():
    cfg = {
        "port": 8080,
        "host": "0.0.0.0",
        "token": "",
        "dataDir": "data",
        "logDir": "logs",
        "auth": {"sessionHours": 8},
        "adminPassword": "",
    }
    p = ROOT / "config.json"
    if p.exists():
        try:
            cfg.update(json.loads(p.read_text(encoding="utf-8-sig")))
        except Exception as e:
            print("config.json 读取失败，使用默认配置: %s" % e, file=sys.stderr)
    cfg["port"] = int(os.environ.get("ERP_PORT", cfg["port"]))
    cfg["host"] = os.environ.get("ERP_HOST", cfg["host"])
    if "ERP_TOKEN" in os.environ:
        cfg["token"] = os.environ["ERP_TOKEN"]
    return cfg


CONFIG = load_config()
DATA_DIR = ROOT / CONFIG.get("dataDir", "data")
LOG_DIR = ROOT / CONFIG.get("logDir", "logs")
DATA_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)
DATA_FILE = DATA_DIR / "db.json"
WEB_DIR = APP_DIR / "web"
PHOTO_DIR = DATA_DIR / "photos"
PHOTO_DIR.mkdir(parents=True, exist_ok=True)
MAX_PHOTO_BYTES = 3 * 1024 * 1024
LOCK = threading.RLock()

for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "server.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)
LOG = logging.getLogger("erp")


def save_db(data):
    tmp = DATA_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(str(tmp), str(DATA_FILE))


def save_photo(data_uri, mid):
    """把 base64 data URI 落盘为 jpg，返回可访问的相对地址。"""
    if not data_uri or not isinstance(data_uri, str):
        return None
    b64 = data_uri.split(",", 1)[1] if data_uri.startswith("data:") else data_uri
    try:
        raw = base64.b64decode(b64, validate=False)
    except Exception:
        return None
    if not raw or len(raw) > MAX_PHOTO_BYTES:
        return None
    name = "%s.jpg" % mid
    try:
        (PHOTO_DIR / name).write_bytes(raw)
    except Exception as e:
        LOG.warning("照片写入失败: %s", e)
        return None
    return "/v1/inventory/photos/%s" % name


def load_db():
    if DATA_FILE.exists():
        try:
            return json.loads(DATA_FILE.read_text(encoding="utf-8-sig"))
        except Exception as e:
            backup = DATA_FILE.with_suffix(".corrupt.json")
            try:
                DATA_FILE.replace(backup)
            except Exception:
                pass
            LOG.warning("数据文件损坏，已备份为 %s 并重建: %s", backup, e)
    data = seed.build_db()
    save_db(data)
    return data


DB = load_db()
AUTH = auth.AuthStore(DATA_DIR, CONFIG)
if AUTH.initial_password:
    LOG.warning("首次启动：已创建管理员 admin，初始密码见 %s", AUTH.credential_file)


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def by_id(items, item_id):
    return next((x for x in items if x["id"] == item_id), None)


def require(cond, message, status=400):
    if not cond:
        raise ApiError(status, message)


def today():
    return datetime.now().strftime("%Y-%m-%d")


def new_sales_order(body):
    import uuid
    items = body.get("items") or []
    norm_items = []
    for i, it in enumerate(items):
        norm_items.append({
            "id": it.get("id") or str(uuid.uuid4()),
            "productName": it.get("productName", ""),
            "quantity": int(it.get("quantity", 1)),
            "unitPrice": float(it.get("unitPrice", 0)),
        })
    require(bool(body.get("customerName")), "customerName 不能为空")
    amount = float(body.get("amount") or sum(x["quantity"] * x["unitPrice"] for x in norm_items))
    return {
        "id": body.get("id") or str(uuid.uuid4()),
        "code": body.get("code") or "SO-%s-%04d" % (datetime.now().strftime("%Y"), len(DB["sales"]) + 1024),
        "customerName": body.get("customerName", ""),
        "date": body.get("date") or today(),
        "amount": amount,
        "status": body.get("status", "草稿"),
        "owner": body.get("owner", "管理员"),
        "items": norm_items,
        "remark": body.get("remark", ""),
    }


def search_outbound(query):
    """仓储出库查找：按关键词 / 仓库 / 日期区间 / 经办人 / SKU 过滤出库流水。

    返回匹配明细、汇总统计以及筛选项可选值，供网页与 iOS 共用。
    """
    q = (query.get("q") or "").strip().lower()
    warehouse = (query.get("warehouse") or "").strip()
    date_from = (query.get("date_from") or "").strip()
    date_to = (query.get("date_to") or "").strip()
    operator = (query.get("operator") or "").strip().lower()
    sku = (query.get("sku") or "").strip().lower()
    typ = (query.get("type") or "出库").strip()
    try:
        limit = max(1, min(1000, int(query.get("limit") or 200)))
    except (TypeError, ValueError):
        limit = 200

    def haystack(m):
        return " ".join(str(m.get(k) or "") for k in
                        ("code", "productName", "sku", "warehouse",
                         "operatorName", "receiver", "note")).lower()

    matched = []
    for m in DB["movements"]:
        if typ and typ != "全部" and m.get("type") != typ:
            continue
        if warehouse and (m.get("warehouse") or "") != warehouse:
            continue
        if date_from and (m.get("date") or "") < date_from:
            continue
        if date_to and (m.get("date") or "") > date_to:
            continue
        if q and q not in haystack(m):
            continue
        if operator and operator not in str(m.get("operatorName") or "").lower():
            continue
        if sku and sku not in ("%s %s" % (m.get("sku") or "",
                                          m.get("productName") or "")).lower():
            continue
        matched.append(m)

    matched.sort(key=lambda m: (m.get("date") or "", m.get("code") or ""),
                 reverse=True)
    by_wh = {}
    for m in matched:
        w = m.get("warehouse") or "未指定"
        d = by_wh.setdefault(w, {"name": w, "count": 0, "quantity": 0})
        d["count"] += 1
        d["quantity"] += int(m.get("quantity") or 0)
    all_out = [m for m in DB["movements"] if m.get("type") == "出库"]
    return {
        "items": matched[:limit],
        "total": len(matched),
        "limit": limit,
        "summary": {
            "count": len(matched),
            "totalQuantity": sum(int(m.get("quantity") or 0) for m in matched),
            "warehouses": sorted(by_wh.values(), key=lambda x: -x["quantity"]),
            "latestDate": matched[0].get("date") if matched else "",
        },
        "options": {
            "warehouses": sorted({m.get("warehouse") or "未指定" for m in all_out}),
            "operators": sorted({m.get("operatorName") or "—" for m in all_out}),
        },
        "filters": {"q": q, "warehouse": warehouse, "date_from": date_from,
                    "date_to": date_to, "operator": operator, "sku": sku,
                    "type": typ},
    }


def create_outbound(body, token):
    """登记一张出库单：校验库存、扣减数量、写出库流水。"""
    sku = str(body.get("sku") or "").strip()
    require(sku, "缺少商品 SKU")
    try:
        qty = int(body.get("quantity") or 0)
    except (TypeError, ValueError):
        qty = 0
    require(qty > 0, "出库数量必须大于 0")
    item = next((i for i in DB["inventory"]
                 if str(i.get("sku") or "").lower() == sku.lower()
                 or str(i.get("id") or "").lower() == sku.lower()), None)
    require(item is not None, "未找到该 SKU 的库存记录，请先入库", 404)
    warehouse = str(body.get("warehouse") or "").strip() or item.get("warehouse") or "主仓"
    require(int(item.get("quantity") or 0) >= qty,
            "库存不足（当前 %s %s）" % (item.get("quantity"), item.get("unit", "")))
    receiver = str(body.get("receiver") or "").strip()[:80]
    note = str(body.get("note") or "").strip()[:200]
    date_s = str(body.get("date") or "").strip() or today()
    who = AUTH.user_for_token(token) or {}
    with LOCK:
        item["quantity"] = int(item["quantity"]) - qty
        item["updatedAt"] = today()
        seq = 1 + sum(1 for m in DB["movements"]
                      if str(m.get("code") or "").startswith("CK-"))
        mid = "MV-%d" % int(datetime.now().timestamp() * 1000)
        mv = {
            "id": mid,
            "code": "CK-%s-%04d" % (datetime.now().strftime("%Y"), seq),
            "productName": item["productName"], "sku": item.get("sku") or sku,
            "type": "出库", "quantity": qty, "warehouse": warehouse,
            "date": date_s, "unit": item.get("unit", "件"),
            "operatorName": who.get("displayName") or who.get("username") or "管理员",
            "receiver": receiver, "note": note, "source": "outbound",
        }
        DB["movements"].insert(0, mv)
        save_db(DB)
    return 201, {"ok": True, "movement": mv, "item": item,
                 "message": "已出库 %d %s" % (qty, item.get("unit", ""))}


def dispatch(method, segs, query, body, token=""):
    """返回 (status_code, response_object)"""
    global DB
    if len(segs) < 2 or segs[0] != "v1":
        raise ApiError(404, "接口不存在")

    resource = segs[1]

    # ---- 认证 / 账号 ----
    if resource == "auth":
        action = segs[2] if len(segs) > 2 else ""
        if action == "login" and method == "POST":
            result = AUTH.login(body.get("username", ""), body.get("password", ""))
            if not result:
                raise ApiError(401, "用户名或密码错误")
            tk, user, exp = result
            return 200, {"token": tk, "user": user, "expiresAt": exp,
                         "serverTime": datetime.now().isoformat(timespec="seconds")}
        current = AUTH.user_for_token(token)
        if action == "me" and method == "GET":
            require(current is not None, "登录已失效", 401)
            return 200, current
        if action == "logout" and method == "POST":
            AUTH.logout(token)
            return 200, {"ok": True}
        if action == "password" and method == "POST":
            require(current is not None, "登录已失效", 401)
            try:
                AUTH.change_password(current["username"], body.get("oldPassword", ""),
                                     body.get("newPassword", ""))
            except (ValueError, PermissionError) as err:
                raise ApiError(400, str(err))
            return 200, {"ok": True, "message": "密码已修改，请重新登录"}
        if action == "users" and method == "GET":
            require(current is not None, "登录已失效", 401)
            return 200, AUTH.list_users()
        if action == "users" and method == "POST":
            require(current is not None, "登录已失效", 401)
            try:
                u = AUTH.add_user(body.get("username", ""), body.get("password", ""),
                                  body.get("displayName", ""), body.get("role", "user"),
                                  current.get("role", "user"))
            except (ValueError, PermissionError) as err:
                raise ApiError(400, str(err))
            return 201, u
        if action == "users" and len(segs) == 4 and method == "PATCH":
            require(current is not None, "登录已失效", 401)
            try:
                u = AUTH.set_enabled(segs[3], body.get("enabled", True), current.get("role", "user"))
            except (ValueError, PermissionError) as err:
                raise ApiError(400, str(err))
            return 200, u

    # ---- 工作台 ----
    if resource == "dashboard" and len(segs) == 3 and segs[2] == "summary" and method == "GET":
        return 200, seed.dashboard(DB)

    # ---- 报表 ----
    if resource == "reports" and len(segs) == 3 and segs[2] == "overview" and method == "GET":
        return 200, seed.reports(DB)

    # ---- 元信息 / 重置 ----
    if resource == "meta" and method == "GET":
        return 200, {"version": VERSION, "endpoints": API_DOCS,
                     "authRequired": True, "time": datetime.now().isoformat()}
    if resource == "admin" and len(segs) == 3 and segs[2] == "reset" and method == "POST":
        with LOCK:
            DB = seed.build_db()
            save_db(DB)
        return 200, {"ok": True, "message": "全部业务数据已清空"}

    # ---- 基础资料 ----
    if resource == "master" and len(segs) == 3 and method == "GET":
        mapping = {"customers": "customers", "suppliers": "suppliers", "products": "products"}
        key = mapping.get(segs[2])
        if key:
            return 200, DB[key]

    # ---- 销售订单 ----
    if resource == "sales-orders":
        if len(segs) == 2 and method == "GET":
            q = (query.get("q") or "").strip().lower()
            st = query.get("status")
            return 200, [o for o in DB["sales"]
                         if (not q or q in o["code"].lower() or q in o["customerName"].lower())
                         and (not st or o["status"] == st)]
        if len(segs) == 2 and method == "POST":
            with LOCK:
                order = new_sales_order(body)
                DB["sales"].insert(0, order)
                save_db(DB)
            return 201, order
        if len(segs) >= 3:
            order = by_id(DB["sales"], segs[2])
            require(order is not None, "订单不存在", 404)
            if len(segs) == 3 and method == "GET":
                return 200, order
            if len(segs) == 4 and segs[3] == "status" and method == "PATCH":
                status = body.get("status")
                require(status in seed.ORDER_STATUSES, "非法状态: %s" % status)
                with LOCK:
                    order["status"] = status
                    save_db(DB)
                return 200, {"ok": True, "id": order["id"], "status": status}

    # ---- 采购订单 ----
    if resource == "purchase-orders":
        if len(segs) == 2 and method == "GET":
            q = (query.get("q") or "").strip().lower()
            st = query.get("status")
            return 200, [o for o in DB["purchases"]
                         if (not q or q in o["code"].lower() or q in o["supplierName"].lower())
                         and (not st or o["status"] == st)]
        if len(segs) >= 3:
            order = by_id(DB["purchases"], segs[2])
            require(order is not None, "采购单不存在", 404)
            if len(segs) == 3 and method == "GET":
                return 200, order
            if len(segs) == 4 and segs[3] == "status" and method == "PATCH":
                status = body.get("status")
                require(status in seed.PURCHASE_STATUSES, "非法状态: %s" % status)
                with LOCK:
                    order["status"] = status
                    save_db(DB)
                return 200, {"ok": True, "id": order["id"], "status": status}

    # ---- 库存 ----
    if resource == "inventory":
        if len(segs) == 3 and segs[2] == "items" and method == "GET":
            q = (query.get("q") or "").strip().lower()
            low = (query.get("low_stock") or "").lower() in ("1", "true", "yes")
            return 200, [i for i in DB["inventory"]
                         if (not q or q in i["productName"].lower() or q in i["sku"].lower())
                         and (not low or i["quantity"] <= i["safetyStock"])]
        if len(segs) == 3 and segs[2] == "movements" and method == "GET":
            return 200, DB["movements"]
        # 仓储出库查找模块
        if len(segs) == 4 and segs[2] == "outbound" and segs[3] == "search" and method == "GET":
            return 200, search_outbound(query)
        if len(segs) == 3 and segs[2] == "outbound" and method == "POST":
            return create_outbound(body, token)
        if len(segs) == 3 and segs[2] == "inbound" and method == "POST":
            sku = str(body.get("sku") or "").strip()
            require(sku, "缺少商品编码")
            try:
                qty = int(body.get("quantity") or 0)
            except (TypeError, ValueError):
                qty = 0
            require(qty > 0, "入库数量必须大于 0")
            warehouse = str(body.get("warehouse") or "").strip() or "主仓"
            note = str(body.get("note") or "").strip()[:200]
            item = next((i for i in DB["inventory"] if i["sku"].lower() == sku.lower()), None)
            if item is None:
                prod = next((p for p in DB["products"] if p["sku"].lower() == sku.lower()), None)
                # 商品档案里没有该 SKU 时也允许入库：以 SKU 作为品名建档，
                # 避免仓库现场因为档案没维护而卡住收货；后续可在基础资料里补充名称。
                item = {
                    "id": "INV-%d" % int(datetime.now().timestamp() * 1000),
                    "sku": prod["sku"] if prod else sku,
                    "productName": prod["name"] if prod else sku,
                    "warehouse": warehouse, "quantity": 0,
                    "safetyStock": 0, "unit": (prod or {}).get("unit", "件"),
                    "updatedAt": today(),
                }
                DB["inventory"].append(item)
            with LOCK:
                item["quantity"] = int(item["quantity"]) + qty
                item["updatedAt"] = today()
                who = AUTH.user_for_token(token) or {}
                mid = "MV-%d" % int(datetime.now().timestamp() * 1000)
                mv = {
                    "id": mid,
                    "code": "MV-%s-%04d" % (datetime.now().strftime("%Y"), len(DB["movements"]) + 1),
                    "productName": item["productName"],
                    "type": "入库", "quantity": qty, "warehouse": warehouse,
                    "date": today(),
                    "operatorName": who.get("displayName") or who.get("username") or "管理员",
                    "source": "camera" if body.get("source") == "camera" else "manual",
                    "note": note,
                }
                photo_url = save_photo(body.get("photo"), mid)
                if photo_url:
                    mv["photoUrl"] = photo_url
                ocr = str(body.get("ocrText") or "").strip()
                if ocr:
                    mv["ocrText"] = ocr[:400]
                DB["movements"].insert(0, mv)
                save_db(DB)
            return 201, {"ok": True, "movement": mv, "item": item,
                         "message": "已入库 %d %s" % (qty, item.get("unit", ""))}

        if len(segs) == 5 and segs[2] == "items" and segs[4] == "adjust" and method == "POST":
            item = by_id(DB["inventory"], segs[3])
            require(item is not None, "库存记录不存在", 404)
            delta = int(body.get("delta", 0))
            with LOCK:
                item["quantity"] = max(0, item["quantity"] + delta)
                item["updatedAt"] = today()
                DB["movements"].insert(0, {
                    "id": "MV-%d" % int(datetime.now().timestamp() * 1000),
                    "code": "MV-%s-%04d" % (datetime.now().strftime("%Y"), len(DB["movements"]) + 1),
                    "productName": item["productName"],
                    "type": "入库" if delta >= 0 else "出库",
                    "quantity": abs(delta), "warehouse": item["warehouse"],
                    "date": today(), "operatorName": "管理员",
                })
                save_db(DB)
            return 200, {"ok": True, "id": item["id"], "quantity": item["quantity"]}

    # ---- 生产工单 ----
    if resource == "work-orders":
        if len(segs) == 2 and method == "GET":
            st = query.get("status")
            return 200, [o for o in DB["workOrders"] if not st or o["status"] == st]
        if len(segs) == 4 and segs[3] == "progress" and method == "PATCH":
            order = by_id(DB["workOrders"], segs[2])
            require(order is not None, "工单不存在", 404)
            done = max(0, min(order["planQty"], int(body.get("doneQty", 0))))
            with LOCK:
                order["doneQty"] = done
                if done >= order["planQty"]:
                    order["status"] = "已完成"
                elif order["status"] == "待排产":
                    order["status"] = "生产中"
                save_db(DB)
            return 200, {"ok": True, "id": order["id"], "doneQty": done, "status": order["status"]}

    # ---- 应收应付 ----
    if resource == "invoices":
        if len(segs) == 2 and method == "GET":
            typ, st = query.get("type"), query.get("status")
            return 200, [o for o in DB["invoices"]
                         if (not typ or o["type"] == typ) and (not st or o["status"] == st)]
        if len(segs) == 4 and segs[3] == "settle" and method == "POST":
            inv = by_id(DB["invoices"], segs[2])
            require(inv is not None, "单据不存在", 404)
            amount = max(0.0, float(body.get("amount", 0)))
            with LOCK:
                inv["settled"] = min(inv["amount"], inv["settled"] + amount)
                inv["status"] = "已结算" if inv["settled"] >= inv["amount"] - 0.01 else (
                    "部分结算" if inv["settled"] > 0 else inv["status"])
                save_db(DB)
            return 200, {"ok": True, "id": inv["id"], "settled": inv["settled"], "status": inv["status"]}

    raise ApiError(404, "接口不存在: %s %s" % (method, "/".join(segs)))


class Handler(BaseHTTPRequestHandler):
    server_version = "ERPServer/" + VERSION
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        LOG.info("%s %s", self.address_string(), fmt % args)

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")

    def _send(self, status, obj=None, raw=None, ctype="application/json; charset=utf-8"):
        if raw is None:
            raw = json.dumps(obj if obj is not None else {}, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(raw)

    def do_OPTIONS(self):
        self._send(204, raw=b"")

    def do_HEAD(self):
        self.handle_request()

    def do_GET(self):
        self.handle_request()

    def do_POST(self):
        self.handle_request()

    def do_PATCH(self):
        self.handle_request()

    def do_PUT(self):
        self.handle_request()

    def do_DELETE(self):
        self.handle_request()

    def serve_static(self, path):
        if path in ("/", "/index.html", "/index.htm"):
            target = WEB_DIR / "index.html"
        else:
            rel = path.lstrip("/")
            target = (WEB_DIR / rel).resolve()
            try:
                target.relative_to(WEB_DIR.resolve())
            except ValueError:
                return self._send(404, {"error": "not found"})
        if not target.is_file():
            return self._send(404, {"error": "not found", "path": path})
        ext = target.suffix.lower()
        ctype = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
                 ".js": "application/javascript; charset=utf-8",
                 ".json": "application/json; charset=utf-8",
                 ".svg": "image/svg+xml", ".png": "image/png", ".ico": "image/x-icon"}.get(ext, "application/octet-stream")
        return self._send(200, raw=target.read_bytes(), ctype=ctype)

    def handle_request(self):
        parsed = urlparse(self.path)
        path = unquote(parsed.path)
        query = {k: v[-1] for k, v in parse_qs(parsed.query).items()}

        if self.command == "GET" and not path.startswith("/v1/") and path != "/health":
            return self.serve_static(path)

        if path == "/health":
            return self._send(200, {
                "status": "ok", "service": "云智 ERP REST v1", "version": VERSION,
                "time": datetime.now().isoformat(), "authEnabled": True, "records": {
                    "sales": len(DB["sales"]), "purchases": len(DB["purchases"]),
                    "inventory": len(DB["inventory"]), "workOrders": len(DB["workOrders"]),
                    "invoices": len(DB["invoices"]),
                },
            })

        # 鉴权：登录接口 / 健康检查 / 静态页面放行，其余 /v1/* 需有效会话或静态运维 Token
        raw_auth = self.headers.get("Authorization", "")
        token = raw_auth[7:].strip() if raw_auth.startswith("Bearer ") else ""
        is_login = path.rstrip("/") == "/v1/auth/login"
        if path.startswith("/v1/") and not is_login:
            static_token = CONFIG.get("token", "")
            ok = bool(static_token and token == static_token) or (AUTH.user_for_token(token) is not None)
            if not ok:
                return self._send(401, {"error": "unauthorized", "message": "请先登录或提供有效令牌"})

        if self.command == "GET" and path.startswith("/v1/inventory/photos/"):
            name = path.rsplit("/", 1)[-1]
            target = (PHOTO_DIR / name).resolve()
            try:
                target.relative_to(PHOTO_DIR.resolve())
            except ValueError:
                return self._send(404, {"error": "not found"})
            if not target.is_file():
                return self._send(404, {"error": "photo_not_found"})
            return self._send(200, raw=target.read_bytes(), ctype="image/jpeg")

        body = {}
        if self.command in ("POST", "PATCH", "PUT"):
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b""
            if raw:
                try:
                    body = json.loads(raw.decode("utf-8"))
                except Exception:
                    return self._send(400, {"error": "invalid_json", "message": "请求体不是合法 JSON"})

        segs = [s for s in path.split("/") if s]
        try:
            status, obj = dispatch(self.command, segs, query, body, token)
            return self._send(status, obj)
        except ApiError as e:
            return self._send(e.status, {"error": "request_failed", "message": e.message})
        except Exception as e:
            LOG.exception("处理请求异常: %s %s", self.command, path)
            return self._send(500, {"error": "internal_error", "message": str(e)})


def main():
    import argparse
    ap = argparse.ArgumentParser(description="云智 ERP REST v1 服务")
    ap.add_argument("--port", type=int, default=CONFIG["port"])
    ap.add_argument("--host", default=CONFIG["host"])
    ap.add_argument("--token", default=None, help="覆盖 config.json 中的 Bearer Token")
    ap.add_argument("--reset", action="store_true", help="清空数据后启动（默认空库）")
    ap.add_argument("--demo", action="store_true", help="启动时注入演示数据（仅演示用）")
    args = ap.parse_args()

    if args.token is not None:
        CONFIG["token"] = args.token
    if args.reset or args.demo:
        global DB
        DB = seed.demo_db() if args.demo else seed.build_db()
        save_db(DB)

    port, host = args.port, args.host
    srv = ThreadingHTTPServer((host, port), Handler)
    srv.daemon_threads = True
    LOG.info("=" * 60)
    LOG.info("云智 ERP REST v1  v%s  已启动", VERSION)
    LOG.info("监听: http://%s:%d", host, port)
    LOG.info("管理台: http://localhost:%d/", port)
    LOG.info("健康检查: http://localhost:%d/health", port)
    LOG.info("数据文件: %s", DATA_FILE)
    LOG.info("鉴权: %s", "Bearer Token 已启用" if CONFIG.get("token") else "未启用（直接访问）")
    LOG.info("=" * 60)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        LOG.info("正在停止服务...")
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()

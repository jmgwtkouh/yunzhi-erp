# -*- coding: utf-8 -*-
"""演示种子数据。字段名与 iOS 工程 Domain/Models.swift 严格一致。"""
from datetime import date

TODAY = date.today().isoformat()

CUSTOMERS_RAW = [
    ("华为技术有限公司", "陈立", "138****2201", "深圳", "战略客户", 1286400),
    ("比亚迪股份有限公司", "刘敏", "139****8872", "深圳", "战略客户", 986200),
    ("海尔智家", "王建国", "137****4410", "青岛", "重要客户", 452800),
    ("格力电器", "赵雪", "136****9032", "珠海", "重要客户", 318500),
    ("宁德时代", "周涛", "135****6621", "宁德", "战略客户", 1542000),
    ("联想集团", "孙悦", "188****1134", "北京", "普通客户", 126700),
    ("小米科技", "吴凡", "186****7745", "北京", "重要客户", 267300),
    ("京东世纪贸易", "郑楠", "185****3390", "北京", "普通客户", 89600),
    ("顺丰速运", "何俊", "133****5567", "深圳", "普通客户", 74200),
    ("美的集团", "林妍", "189****2288", "佛山", "重要客户", 391400),
    ("三一重工", "马超", "150****9911", "长沙", "普通客户", 208900),
    ("TCL 科技", "徐静", "151****4432", "惠州", "普通客户", 63800),
]

SUPPLIERS_RAW = [
    ("宝钢股份", "李工", "021****6621", "原材料", 5, 682000),
    ("立讯精密", "张经理", "0755****2208", "电子元件", 5, 421300),
    ("京东方科技", "钱总", "010****5580", "显示模组", 4, 356800),
    ("万华化学", "孙工", "0535****7712", "化工材料", 4, 198400),
    ("富士康工业互联网", "刘主管", "0755****3301", "代工服务", 5, 512600),
    ("紫金矿业", "陈经理", "0597****8842", "金属材料", 3, 143200),
    ("汇川技术", "周工", "0755****9903", "伺服驱动", 5, 287900),
    ("中航光电", "吴经理", "0379****1124", "连接器", 4, 96500),
    ("浙江中控", "郑工", "0571****4430", "控制系统", 4, 178300),
    ("施耐德电气", "冯总", "021****7756", "低压电气", 5, 233700),
]

PRODUCTS_RAW = [
    ("IS-200", "工业传感器 IS-200", "传感与检测", "件", 1280, 742, 1860, 500, "sensor"),
    ("SM-750", "伺服电机 SM-750", "驱动与传动", "台", 4680, 2910, 342, 120, "motor"),
    ("PLC-1200", "PLC 控制器 S7-1200", "控制系统", "台", 3250, 1980, 88, 150, "cpu"),
    ("AL-6063", "铝合金型材 6063", "原材料", "米", 86, 42, 12800, 3000, "square"),
    ("BR-6204", "精密轴承 6204", "机械零件", "套", 156, 78, 4200, 1000, "circle"),
    ("HP-32", "液压泵 HP-32", "液压气动", "台", 2860, 1640, 96, 80, "drop"),
    ("GW-4G", "工业网关 GW-4G", "通讯模块", "台", 1980, 1050, 512, 200, "network"),
    ("HMI-10", "触摸屏 HMI-10", "人机界面", "台", 2380, 1320, 274, 180, "display"),
    ("CB-3P", "断路器 CB-3P", "低压电气", "只", 320, 168, 2100, 600, "bolt"),
    ("WH-18", "线束 WH-18", "辅材", "套", 96, 38, 8600, 2000, "cable"),
    ("EN-45", "编码器 EN-45", "传感与检测", "只", 890, 510, 640, 300, "dial"),
    ("VL-25", "电磁阀 VL-25", "液压气动", "只", 460, 235, 1180, 400, "valve"),
]

ORDER_STATUSES = ["草稿", "待审核", "已确认", "发货中", "已完成", "已取消"]
PURCHASE_STATUSES = ["草稿", "待审批", "已下单", "到货中", "已入库", "已取消"]
WORK_STATUSES = ["待排产", "生产中", "质检中", "已完成", "已暂停"]
INVOICE_STATUSES = ["未结算", "部分结算", "已结算", "已逾期"]
OWNERS = ["陈曦", "刘洋", "王倩", "赵鹏", "林晓", "周宇"]
WAREHOUSES = ["华东主仓", "华南分仓", "华北备件仓"]

SALES_TREND = [("12月", 286), ("1月", 312), ("2月", 268), ("3月", 358),
               ("4月", 402), ("5月", 376), ("6月", 448), ("7月", 492),
               ("8月", 466), ("9月", 528), ("10月", 574), ("11月", 612)]
PURCHASE_TREND = [(m, int(v * 0.58)) for m, v in SALES_TREND]


def _points(pairs):
    return [{"label": m, "value": v} for m, v in pairs]


def empty_db():
    """生产默认：空库，不预置任何演示业务数据。"""
    return {
        "sales": [], "purchases": [], "inventory": [], "movements": [],
        "workOrders": [], "invoices": [], "customers": [], "suppliers": [],
        "products": [], "meta": {"version": 1, "createdAt": TODAY, "source": "empty"},
    }


def build_db():
    """默认初始化为空库；演示数据见 demo_db()，仅 --demo 启动参数使用。"""
    return empty_db()


def demo_db():
    customers = [
        {"id": "C%d" % (1001 + i), "name": r[0], "contact": r[1], "phone": r[2],
         "city": r[3], "level": r[4], "receivable": r[5],
         "createdAt": "2026-%02d-%02d" % (1 + i % 9, 10 + i % 18)}
        for i, r in enumerate(CUSTOMERS_RAW)
    ]
    suppliers = [
        {"id": "S%d" % (2001 + i), "name": r[0], "contact": r[1], "phone": r[2],
         "category": r[3], "rating": r[4], "payable": r[5],
         "createdAt": "2026-%02d-%02d" % (1 + i % 9, 5 + i % 20)}
        for i, r in enumerate(SUPPLIERS_RAW)
    ]
    products = [
        {"id": "P%d" % (3001 + i), "sku": r[0], "name": r[1], "category": r[2],
         "unit": r[3], "price": r[4], "cost": r[5], "stock": r[6],
         "safetyStock": r[7], "symbol": r[8]}
        for i, r in enumerate(PRODUCTS_RAW)
    ]

    sales = []
    for i in range(24):
        p1 = products[i % len(products)]
        p2 = products[(i + 5) % len(products)]
        q1, q2 = 20 + (i * 7) % 180, 5 + (i * 3) % 40
        items = [
            {"id": "L%d-1" % i, "productName": p1["name"], "quantity": q1, "unitPrice": p1["price"]},
            {"id": "L%d-2" % i, "productName": p2["name"], "quantity": q2, "unitPrice": p2["price"]},
        ]
        sales.append({
            "id": "SO%d" % (4001 + i), "code": "SO-2026-%04d" % (1024 + i),
            "customerName": customers[i % len(customers)]["name"],
            "date": "2026-11-%02d" % (1 + i % 7),
            "amount": sum(x["quantity"] * x["unitPrice"] for x in items),
            "status": ORDER_STATUSES[(i * 5) % len(ORDER_STATUSES)],
            "owner": OWNERS[i % len(OWNERS)], "items": items,
            "remark": "客户要求分批交付，优先安排华东仓发货。" if i % 3 == 0 else "按标准交期执行",
        })

    purchases = []
    for i in range(16):
        p = products[(i * 2) % len(products)]
        qty = 100 + (i * 37) % 900
        items = [{"id": "PL%d" % i, "productName": p["name"], "quantity": qty, "unitPrice": p["cost"]}]
        purchases.append({
            "id": "PO%d" % (5001 + i), "code": "PO-2026-%04d" % (2048 + i),
            "supplierName": suppliers[i % len(suppliers)]["name"],
            "date": "2026-10-%02d" % (20 + i % 10),
            "eta": "2026-11-%02d" % (8 + i % 20),
            "amount": qty * p["cost"], "status": PURCHASE_STATUSES[(i * 3) % len(PURCHASE_STATUSES)],
            "owner": ["采购一部", "采购二部", "供应链中心"][i % 3], "items": items,
        })

    inventory = []
    for i, p in enumerate(products):
        for j, w in enumerate(WAREHOUSES):
            if (i + j) % 3 == 1:
                continue
            qty = max(0, p["stock"] // (j + 2) - (i * 13) % 60)
            inventory.append({
                "id": "IV%d" % (6000 + i * 10 + j), "sku": p["sku"],
                "productName": p["name"], "warehouse": w, "quantity": qty,
                "safetyStock": max(20, p["safetyStock"] // 2), "unit": p["unit"],
                "updatedAt": "2026-11-%02d" % (1 + (i + j) % 7),
            })

    movements = []
    for i in range(18):
        p = products[(i * 3) % len(products)]
        movements.append({
            "id": "MV%d" % (7001 + i), "code": "MV-2026-%04d" % (3300 + i),
            "productName": p["name"],
            "type": ["入库", "出库", "出库", "调拨", "入库"][i % 5],
            "quantity": 20 + (i * 17) % 460, "warehouse": WAREHOUSES[i % 3],
            "date": "2026-11-%02d" % (1 + i % 7),
            "operatorName": ["张伟", "李娜", "王强", "陈静"][i % 4],
        })

    work_orders = []
    for i in range(12):
        plan = 200 + (i * 80) % 1200
        st = WORK_STATUSES[(i * 3) % len(WORK_STATUSES)]
        done = 0 if st == "待排产" else plan if st == "已完成" else int(plan * (0.2 + (i % 7) * 0.1))
        work_orders.append({
            "id": "WO%d" % (8001 + i), "code": "MO-2026-%04d" % (4400 + i),
            "productName": products[i % len(products)]["name"],
            "planQty": plan, "doneQty": min(done, plan),
            "line": ["A 线（总装）", "B 线（精密）", "C 线（包装）"][i % 3],
            "startDate": "2026-10-%02d" % (20 + i % 10),
            "dueDate": "2026-11-%02d" % (10 + i % 18), "status": st,
        })

    invoices = []
    for i in range(16):
        typ = "应收" if i % 2 == 0 else "应付"
        amount = float(38000 + (i * 27350) % 620000)
        st = INVOICE_STATUSES[(i * 5) % len(INVOICE_STATUSES)]
        settled = amount if st == "已结算" else amount * 0.45 if st == "部分结算" else 0
        invoices.append({
            "id": "IN%d" % (9001 + i),
            "code": "%s-2026-%04d" % ("AR" if typ == "应收" else "AP", 5500 + i),
            "counterparty": (customers[i % len(customers)]["name"] if typ == "应收"
                             else suppliers[i % len(suppliers)]["name"]),
            "type": typ, "amount": amount, "settled": settled,
            "dueDate": "2026-11-%02d" % (8 + i % 22), "status": st,
        })

    return {
        "sales": sales, "purchases": purchases, "inventory": inventory,
        "movements": movements, "workOrders": work_orders, "invoices": invoices,
        "customers": customers, "suppliers": suppliers, "products": products,
        "meta": {"version": 1, "createdAt": TODAY, "source": "seed"},
    }


def dashboard(db):
    sales = db["sales"]
    revenue = sum(o["amount"] for o in sales
                  if o["status"] not in ("已取消", "草稿"))
    pending_sales = sum(1 for o in sales if o["status"] == "待审核")
    pending_purchase = sum(1 for o in db["purchases"] if o["status"] == "待审批")
    unscheduled = sum(1 for o in db["workOrders"] if o["status"] == "待排产")
    overdue = sum(1 for o in db["invoices"]
                  if o["type"] == "应收" and o["status"] == "已逾期")
    low = sorted({i["productName"] for i in db["inventory"]
                  if i["quantity"] <= i["safetyStock"]})
    receivable = sum(o["amount"] - o["settled"] for o in db["invoices"]
                     if o["type"] == "应收" and o["status"] != "已结算")

    kpis = [
        {"id": "k1", "title": "本月销售额", "value": "%.1f" % (revenue / 10000),
         "unit": "万元", "delta": 0, "symbol": "chart.line.uptrend.xyaxis", "tone": "info"},
        {"id": "k2", "title": "待处理单据", "value": str(pending_sales + pending_purchase),
         "unit": "单", "delta": 0, "symbol": "doc.text.magnifyingglass", "tone": "warning"},
        {"id": "k3", "title": "库存预警", "value": str(len(low)),
         "unit": "种", "delta": 0, "symbol": "exclamationmark.triangle", "tone": "danger"},
        {"id": "k4", "title": "应收未结", "value": "%.1f" % (receivable / 10000),
         "unit": "万元", "delta": 0, "symbol": "banknote", "tone": "success"},
    ]
    todos = [
        {"id": "t1", "title": "销售订单待审", "subtitle": "审核后进入发货流程",
         "count": pending_sales, "symbol": "doc.badge.ellipsis", "routeKey": "sales"},
        {"id": "t2", "title": "采购申请待批", "subtitle": "涉及 %d 家供应商" % pending_purchase,
         "count": pending_purchase, "symbol": "cart.badge.questionmark", "routeKey": "purchase"},
        {"id": "t3", "title": "工单待排产", "subtitle": "需分配产线与交期",
         "count": unscheduled, "symbol": "gearshape.2", "routeKey": "production"},
        {"id": "t4", "title": "逾期应收款", "subtitle": "建议今日跟进回款",
         "count": overdue, "symbol": "clock.badge.exclamationmark", "routeKey": "finance"},
    ]
    alerts = ["%s 库存低于安全线，建议补货" % n for n in low[:2]]
    if overdue:
        alerts.append("%d 笔应收账款已逾期，请安排催收" % overdue)
    if not alerts:
        alerts.append("暂无业务数据，请先录入单据" if not sales else "当前无异常，所有指标运行平稳")
    return {
        "kpis": kpis, "todos": todos, "recentOrders": sales[:5],
        "salesTrend": [], "alerts": alerts,
    }


def reports(db):
    """趋势与占比全部来自真实业务数据；空库时返回空图表，不预置演示数值。"""
    def monthly(key):
        agg = {}
        for o in db.get(key, []):
            if o.get("status") == "已取消":
                continue
            k = (o.get("date") or "")[:7]
            agg[k] = agg.get(k, 0) + o.get("amount", 0) / 10000
        return [{"label": k, "value": round(v, 1)} for k, v in sorted(agg.items())]

    tones = ["info", "accent", "success", "warning", "neutral"]
    cat = {}
    for p in db.get("products", []):
        c = p.get("category", "其他")
        cat[c] = cat.get(c, 0) + p.get("stock", 0)
    total_cat = sum(cat.values())
    shares = ([{"name": k, "value": round(v / total_cat * 100, 1), "tone": tones[i % len(tones)]}
               for i, (k, v) in enumerate(sorted(cat.items(), key=lambda x: -x[1]))]
              if total_cat else [])

    wh = {}
    for i in db.get("inventory", []):
        w = i.get("warehouse", "")
        wh[w] = wh.get(w, 0) + i.get("quantity", 0)
    total_wh = sum(wh.values())
    wshares = ([{"name": k, "value": round(v / total_wh * 100, 1), "tone": tones[i % len(tones)]}
                for i, (k, v) in enumerate(sorted(wh.items(), key=lambda x: -x[1]))]
               if total_wh else [])

    return {"salesTrend": monthly("sales"), "purchaseTrend": monthly("purchases"),
            "categoryShare": shares, "warehouseShare": wshares}

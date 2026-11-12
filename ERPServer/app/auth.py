# -*- coding: utf-8 -*-
"""管理登录：PBKDF2 密码哈希 + 会话 Token，仅使用标准库，无第三方依赖。

数据文件（位于 data/ 目录）：
  users.json         账号（仅存 salt / hash，不存明文密码）
  sessions.json      有效会话（服务重启后仍保持登录）
  initial-admin.txt  首次启动时生成的初始管理员凭据
"""
import hashlib
import hmac
import json
import os
import secrets
import threading
from datetime import datetime, timedelta
from pathlib import Path

LOCK = threading.RLock()
ITERATIONS = 120_000


def _hash(password, salt_hex):
    return hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), bytes.fromhex(salt_hex), ITERATIONS
    ).hex()


def _write_json(path, data):
    tmp = Path(str(path) + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(str(tmp), str(path))


def _public(user):
    return {
        "username": user["username"],
        "displayName": user["displayName"],
        "role": user["role"],
        "enabled": user.get("enabled", True),
        "mustChangePassword": user.get("mustChangePassword", False),
        "createdAt": user.get("createdAt", ""),
    }


class AuthStore:
    def __init__(self, data_dir, config):
        self.dir = Path(data_dir)
        self.dir.mkdir(parents=True, exist_ok=True)
        self.users_file = self.dir / "users.json"
        self.sessions_file = self.dir / "sessions.json"
        self.credential_file = self.dir / "initial-admin.txt"
        self.session_hours = int((config.get("auth") or {}).get("sessionHours", 8))
        self.users = {}
        self.sessions = {}
        self.initial_password = None
        with LOCK:
            self._load()
            if not self.users:
                self.initial_password = (config.get("adminPassword")
                                         or secrets.token_urlsafe(9))
                self._create_user("admin", self.initial_password,
                                  "系统管理员", "admin", must_change=True)
                self.credential_file.write_text(
                    "云智 ERP 初始管理员凭据\n"
                    "用户名: admin\n"
                    "密码: %s\n"
                    "请登录后立即在「设置 → 账号安全」修改密码，并删除本文件。\n"
                    % self.initial_password, encoding="utf-8")

    # ---------- 持久化 ----------
    def _load(self):
        if self.users_file.exists():
            try:
                self.users = json.loads(self.users_file.read_text(encoding="utf-8-sig"))
            except Exception:
                self.users = {}
        if self.sessions_file.exists():
            try:
                self.sessions = json.loads(self.sessions_file.read_text(encoding="utf-8-sig"))
            except Exception:
                self.sessions = {}
        now = datetime.now().isoformat(timespec="seconds")
        self.sessions = {k: v for k, v in self.sessions.items()
                         if v.get("expiresAt", "") > now}

    def _save_users(self):
        _write_json(self.users_file, self.users)

    def _save_sessions(self):
        _write_json(self.sessions_file, self.sessions)

    # ---------- 账号 ----------
    def _create_user(self, username, password, display_name, role, must_change=False):
        username = (username or "").strip().lower()
        if not username:
            raise ValueError("用户名不能为空")
        if len(password or "") < 8:
            raise ValueError("密码至少 8 位")
        salt = secrets.token_hex(16)
        self.users[username] = {
            "username": username,
            "displayName": display_name or username,
            "role": role or "user",
            "enabled": True,
            "mustChangePassword": must_change,
            "salt": salt,
            "hash": _hash(password, salt),
            "createdAt": datetime.now().isoformat(timespec="seconds"),
        }
        self._save_users()
        return self.users[username]

    def verify(self, username, password):
        u = self.users.get((username or "").strip().lower())
        if not u or not u.get("enabled", True):
            return None
        if not hmac.compare_digest(u["hash"], _hash(password or "", u["salt"])):
            return None
        return u

    # ---------- 会话 ----------
    def login(self, username, password):
        with LOCK:
            u = self.verify(username, password)
            if not u:
                return None
            token = secrets.token_urlsafe(32)
            exp = (datetime.now() + timedelta(hours=self.session_hours)).isoformat(timespec="seconds")
            self.sessions[token] = {"username": u["username"], "expiresAt": exp}
            self._save_sessions()
            return token, _public(u), exp

    def user_for_token(self, token):
        if not token:
            return None
        with LOCK:
            s = self.sessions.get(token)
            if not s or s.get("expiresAt", "") <= datetime.now().isoformat(timespec="seconds"):
                return None
            u = self.users.get(s["username"])
            return _public(u) if u and u.get("enabled", True) else None

    def logout(self, token):
        with LOCK:
            if token in self.sessions:
                del self.sessions[token]
                self._save_sessions()
        return True

    # ---------- 管理 ----------
    def change_password(self, username, old_password, new_password):
        with LOCK:
            u = self.verify(username, old_password)
            if not u:
                raise ValueError("原密码不正确")
            if len(new_password or "") < 8:
                raise ValueError("新密码至少 8 位")
            salt = secrets.token_hex(16)
            u["hash"] = _hash(new_password, salt)
            u["salt"] = salt
            u["mustChangePassword"] = False
            self._save_users()
            return True

    def list_users(self):
        return [_public(u) for u in self.users.values()]

    def add_user(self, username, password, display_name, role, actor_role="user"):
        if actor_role != "admin":
            raise PermissionError("仅管理员可新建账号")
        with LOCK:
            if (username or "").strip().lower() in self.users:
                raise ValueError("用户名已存在")
            u = self._create_user(username, password, display_name, role)
            return _public(u)

    def set_enabled(self, username, enabled, actor_role="user"):
        if actor_role != "admin":
            raise PermissionError("仅管理员可停用账号")
        with LOCK:
            u = self.users.get((username or "").strip().lower())
            if not u:
                raise ValueError("账号不存在")
            if u["username"] == "admin" and not enabled:
                raise ValueError("不能停用初始管理员账号")
            u["enabled"] = bool(enabled)
            self._save_users()
            for t, s in list(self.sessions.items()):
                if s["username"] == u["username"] and not enabled:
                    del self.sessions[t]
            self._save_sessions()
            return _public(u)

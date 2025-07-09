"use strict";
const common_vendor = require("../common/vendor.js");
const api_auth = require("../api/auth.js");
function decodeJWTPayload(token) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = parts[1];
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - base64.length % 4) % 4);
    return JSON.parse(atob(padded));
  } catch (error) {
    console.error("JWT解码失败:", error);
    return null;
  }
}
const AUTH_REQUIRED_PAGES = [
  "/pages/index/index",
  "/pages/recipes/index",
  "/pages/orders/index",
  "/pages/profile/index"
];
function isAuthRequired(path) {
  return AUTH_REQUIRED_PAGES.some((page) => path.includes(page));
}
function isTokenExpired() {
  try {
    const token = common_vendor.index.getStorageSync("token");
    if (!token) return true;
    const payload = decodeJWTPayload(token);
    if (!payload || !payload.exp) return true;
    const exp = payload.exp * 1e3;
    const now = Date.now();
    return now >= exp;
  } catch (error) {
    console.error("检查token过期状态失败:", error);
    return true;
  }
}
function checkLoginStatus() {
  const hasToken = api_auth.AuthService.isLoggedIn();
  if (!hasToken) return false;
  if (isTokenExpired()) {
    api_auth.AuthService.logout();
    return false;
  }
  return true;
}
function redirectToLogin() {
  common_vendor.index.reLaunch({
    url: "/pages/login/index"
  });
}
function isTokenNearExpiry() {
  try {
    const token = common_vendor.index.getStorageSync("token");
    if (!token) return false;
    const payload = decodeJWTPayload(token);
    if (!payload || !payload.exp) return false;
    const exp = payload.exp * 1e3;
    const now = Date.now();
    const timeUntilExpiry = exp - now;
    return timeUntilExpiry <= 30 * 60 * 1e3;
  } catch (error) {
    console.error("检查token过期时间失败:", error);
    return false;
  }
}
async function autoLoginCheck() {
  try {
    if (checkLoginStatus()) {
      const token = common_vendor.index.getStorageSync("token");
      const payload = decodeJWTPayload(token);
      if (payload && payload.exp) {
        const exp = payload.exp * 1e3;
        const now = Date.now();
        const timeUntilExpiry = exp - now;
        const minutesUntilExpiry = Math.floor(timeUntilExpiry / (60 * 1e3));
        console.log(`Token状态检查: 距离过期还有 ${minutesUntilExpiry} 分钟`);
        if (isTokenNearExpiry()) {
          console.log("Token即将过期，尝试刷新...");
          try {
            await api_auth.AuthService.refreshToken();
            console.log("Token刷新成功");
            return true;
          } catch (error) {
            console.error("Token刷新失败:", error);
            if (error.message && error.message.includes("token not ready for refresh")) {
              console.log("Token尚未到达刷新时间，继续使用当前token");
              return true;
            }
            console.log("Token刷新失败，清除本地存储并尝试静默登录");
            api_auth.AuthService.logout();
          }
        } else {
          console.log("Token仍然有效，无需刷新");
          return true;
        }
      }
    }
    console.log("尝试静默登录...");
    try {
      await api_auth.AuthService.silentLogin();
      console.log("静默登录成功");
      return true;
    } catch (error) {
      console.error("静默登录失败:", error);
      return false;
    }
  } catch (error) {
    console.error("自动登录检查失败:", error);
    return false;
  }
}
async function checkPageAccess(path) {
  if (!isAuthRequired(path)) {
    return true;
  }
  if (checkLoginStatus()) {
    return true;
  }
  const autoLoginSuccess = await autoLoginCheck();
  if (autoLoginSuccess) {
    return true;
  }
  redirectToLogin();
  return false;
}
exports.autoLoginCheck = autoLoginCheck;
exports.checkPageAccess = checkPageAccess;

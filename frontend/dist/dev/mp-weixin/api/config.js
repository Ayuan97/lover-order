"use strict";
function getBaseURL() {
  return "http://192.168.4.15:8081/api/v1";
}
const API_CONFIG = {
  // 开发环境API地址
  BASE_URL: getBaseURL(),
  // 请求超时时间
  TIMEOUT: 1e4,
  // 请求头配置
  HEADERS: {
    "Content-Type": "application/json"
  }
};
const API_ENDPOINTS = {
  // 认证相关
  AUTH: {
    WECHAT_LOGIN: "/auth/wechat/login",
    REFRESH_TOKEN: "/auth/refresh",
    LOGOUT: "/auth/logout"
  },
  // 用户相关
  USER: {
    PROFILE: "/user/profile",
    FAMILY_MEMBERS: "/user/family/members"
  },
  // 菜谱相关
  RECIPES: {
    LIST: "/recipes",
    DETAIL: (id) => `/recipes/${id}`,
    CREATE: "/recipes",
    UPDATE: (id) => `/recipes/${id}`,
    DELETE: (id) => `/recipes/${id}`,
    TOGGLE_FAVORITE: (id) => `/recipes/${id}/favorite`,
    FAVORITES: "/recipes/favorites"
  },
  // 分类相关
  CATEGORIES: {
    LIST: "/categories",
    DETAIL: (id) => `/categories/${id}`,
    STATS: "/categories/stats",
    CREATE: "/categories",
    UPDATE: (id) => `/categories/${id}`,
    DELETE: (id) => `/categories/${id}`,
    SORT: "/categories/sort"
  },
  // 开发测试接口（无需认证）
  DEV: {
    CATEGORIES: "/dev/categories",
    RECIPES: "/dev/recipes",
    CREATE_CATEGORY: "/dev/categories",
    CREATE_RECIPE: "/dev/recipes"
  },
  // 订单相关
  ORDERS: {
    LIST: "/orders",
    DETAIL: (id) => `/orders/${id}`,
    CREATE: "/orders",
    UPDATE_STATUS: (id) => `/orders/${id}/status`,
    CANCEL: (id) => `/orders/${id}/cancel`,
    REPEAT: (id) => `/orders/${id}/repeat`,
    STATS: "/orders/stats",
    SUMMARY: "/orders/summary",
    TODAY: "/orders/today",
    PENDING: "/orders/pending"
  },
  // 家庭相关
  FAMILY: {
    CREATE: "/family",
    INFO: "/family/info",
    UPDATE: "/family/info",
    JOIN: "/family/join",
    LEAVE: "/family/leave",
    DELETE: "/family",
    STATS: "/family/stats"
  },
  // 访客相关
  GUEST: {
    INFO: "/guest/info",
    INVITE_CHECK: "/guest/invite/check",
    REGISTER: "/guest/register",
    INVITE: "/guest/invite",
    LIST: "/guest/list",
    INVITATIONS: "/guest/invitations",
    EXTEND: (id) => `/guest/${id}/extend`,
    REVOKE: (id) => `/guest/${id}/revoke`
  }
};
const HTTP_STATUS = {
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  INTERNAL_SERVER_ERROR: 500
};
const ERROR_MESSAGES = {
  NETWORK_ERROR: "网络连接失败，请检查网络设置",
  TIMEOUT_ERROR: "请求超时，请稍后重试",
  SERVER_ERROR: "服务器错误，请稍后重试",
  UNAUTHORIZED: "登录已过期，请重新登录",
  FORBIDDEN: "没有权限执行此操作",
  NOT_FOUND: "请求的资源不存在",
  UNKNOWN_ERROR: "未知错误，请稍后重试"
};
exports.API_CONFIG = API_CONFIG;
exports.API_ENDPOINTS = API_ENDPOINTS;
exports.ERROR_MESSAGES = ERROR_MESSAGES;
exports.HTTP_STATUS = HTTP_STATUS;

// 获取API基础URL
function getBaseURL(): string {
  // #ifdef MP-WEIXIN
  // 小程序环境下使用localhost（开发环境）
  return 'http://127.0.0.1:8081/api/v1'
  // #endif

  // #ifdef H5
  // H5环境下使用localhost
  return 'http://localhost:8081/api/v1'
  // #endif

  // 默认使用localhost
  return 'http://localhost:8081/api/v1'
}

// API配置
export const API_CONFIG = {
  // 开发环境API地址
  BASE_URL: getBaseURL(),

  // 请求超时时间
  TIMEOUT: 10000,

  // 请求头配置
  HEADERS: {
    'Content-Type': 'application/json',
  }
}

// API端点配置
export const API_ENDPOINTS = {
  // 认证相关
  AUTH: {
    WECHAT_LOGIN: '/auth/wechat/login',
    REFRESH_TOKEN: '/auth/refresh',
    LOGOUT: '/auth/logout',
  },
  
  // 用户相关
  USER: {
    PROFILE: '/user/profile',
    FAMILY_MEMBERS: '/user/family/members',
  },
  
  // 菜谱相关
  RECIPES: {
    LIST: '/recipes',
    DETAIL: (id: number) => `/recipes/${id}`,
    CREATE: '/recipes',
    UPDATE: (id: number) => `/recipes/${id}`,
    DELETE: (id: number) => `/recipes/${id}`,
    TOGGLE_FAVORITE: (id: number) => `/recipes/${id}/favorite`,
    FAVORITES: '/recipes/favorites',
  },
  
  // 分类相关
  CATEGORIES: {
    LIST: '/categories',
    DETAIL: (id: number) => `/categories/${id}`,
    STATS: '/categories/stats',
    CREATE: '/categories',
    UPDATE: (id: number) => `/categories/${id}`,
    DELETE: (id: number) => `/categories/${id}`,
    SORT: '/categories/sort',
  },

  // 开发测试接口（无需认证）
  DEV: {
    CATEGORIES: '/dev/categories',
    RECIPES: '/dev/recipes',
    CREATE_CATEGORY: '/dev/categories',
    CREATE_RECIPE: '/dev/recipes',
  },
  
  // 订单相关
  ORDERS: {
    LIST: '/orders',
    DETAIL: (id: number) => `/orders/${id}`,
    CREATE: '/orders',
    UPDATE_STATUS: (id: number) => `/orders/${id}/status`,
    CANCEL: (id: number) => `/orders/${id}/cancel`,
    REPEAT: (id: number) => `/orders/${id}/repeat`,
    STATS: '/orders/stats',
    SUMMARY: '/orders/summary',
    TODAY: '/orders/today',
    PENDING: '/orders/pending',
  },
  
  // 家庭相关
  FAMILY: {
    CREATE: '/family',
    INFO: '/family/info',
    UPDATE: '/family/info',
    JOIN: '/family/join',
    LEAVE: '/family/leave',
    DELETE: '/family',
    STATS: '/family/stats',
  },
  
  // 访客相关
  GUEST: {
    INFO: '/guest/info',
    INVITE_CHECK: '/guest/invite/check',
    REGISTER: '/guest/register',
    INVITE: '/guest/invite',
    LIST: '/guest/list',
    INVITATIONS: '/guest/invitations',
    EXTEND: (id: number) => `/guest/${id}/extend`,
    REVOKE: (id: number) => `/guest/${id}/revoke`,
  }
}

// 响应状态码
export const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  INTERNAL_SERVER_ERROR: 500,
}

// 错误消息
export const ERROR_MESSAGES = {
  NETWORK_ERROR: '网络连接失败，请检查网络设置',
  TIMEOUT_ERROR: '请求超时，请稍后重试',
  SERVER_ERROR: '服务器错误，请稍后重试',
  UNAUTHORIZED: '登录已过期，请重新登录',
  FORBIDDEN: '没有权限执行此操作',
  NOT_FOUND: '请求的资源不存在',
  VALIDATION_ERROR: '数据验证失败',
  UNKNOWN_ERROR: '未知错误，请稍后重试',
}

"use strict";
var __defProp = Object.defineProperty;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
const common_vendor = require("../common/vendor.js");
const api_config = require("./config.js");
class RequestService {
  constructor() {
    __publicField(this, "baseURL");
    __publicField(this, "timeout");
    __publicField(this, "defaultHeaders");
    this.baseURL = api_config.API_CONFIG.BASE_URL;
    this.timeout = api_config.API_CONFIG.TIMEOUT;
    this.defaultHeaders = api_config.API_CONFIG.HEADERS;
  }
  // 获取存储的token
  getToken() {
    try {
      return common_vendor.index.getStorageSync("token");
    } catch (error) {
      console.error("获取token失败:", error);
      return null;
    }
  }
  // 设置token
  setToken(token) {
    try {
      common_vendor.index.setStorageSync("token", token);
    } catch (error) {
      console.error("设置token失败:", error);
    }
  }
  // 清除token
  clearToken() {
    try {
      common_vendor.index.removeStorageSync("token");
    } catch (error) {
      console.error("清除token失败:", error);
    }
  }
  // 处理请求头
  getHeaders(customHeaders) {
    const headers = { ...this.defaultHeaders, ...customHeaders };
    const token = this.getToken();
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }
    return headers;
  }
  // 处理错误
  handleError(error) {
    var _a;
    console.error("API请求错误:", error);
    if (error.statusCode) {
      switch (error.statusCode) {
        case api_config.HTTP_STATUS.UNAUTHORIZED:
          this.clearToken();
          return {
            code: api_config.HTTP_STATUS.UNAUTHORIZED,
            message: api_config.ERROR_MESSAGES.UNAUTHORIZED
          };
        case api_config.HTTP_STATUS.FORBIDDEN:
          return {
            code: api_config.HTTP_STATUS.FORBIDDEN,
            message: api_config.ERROR_MESSAGES.FORBIDDEN
          };
        case api_config.HTTP_STATUS.NOT_FOUND:
          return {
            code: api_config.HTTP_STATUS.NOT_FOUND,
            message: api_config.ERROR_MESSAGES.NOT_FOUND
          };
        case api_config.HTTP_STATUS.INTERNAL_SERVER_ERROR:
          return {
            code: api_config.HTTP_STATUS.INTERNAL_SERVER_ERROR,
            message: api_config.ERROR_MESSAGES.SERVER_ERROR
          };
        default:
          return {
            code: error.statusCode,
            message: ((_a = error.data) == null ? void 0 : _a.message) || api_config.ERROR_MESSAGES.UNKNOWN_ERROR
          };
      }
    }
    if (error.errMsg) {
      if (error.errMsg.includes("timeout")) {
        return {
          code: -1,
          message: api_config.ERROR_MESSAGES.TIMEOUT_ERROR
        };
      } else if (error.errMsg.includes("fail")) {
        return {
          code: -2,
          message: api_config.ERROR_MESSAGES.NETWORK_ERROR
        };
      }
    }
    return {
      code: -999,
      message: api_config.ERROR_MESSAGES.UNKNOWN_ERROR,
      details: error
    };
  }
  // 发送请求
  async request(url, options = {}) {
    const {
      method = "GET",
      data,
      headers: customHeaders,
      timeout = this.timeout
    } = options;
    const fullUrl = url.startsWith("http") ? url : `${this.baseURL}${url}`;
    const headers = this.getHeaders(customHeaders);
    return new Promise((resolve, reject) => {
      common_vendor.index.request({
        url: fullUrl,
        method,
        data,
        header: headers,
        timeout,
        success: (response) => {
          const { statusCode, data: responseData } = response;
          if (statusCode >= 200 && statusCode < 300) {
            resolve({
              code: statusCode,
              message: "success",
              data: responseData,
              success: true
            });
          } else {
            const error = this.handleError({ statusCode, data: responseData });
            reject(error);
          }
        },
        fail: (error) => {
          const apiError = this.handleError(error);
          reject(apiError);
        }
      });
    });
  }
  // GET请求
  async get(url, params, headers) {
    let fullUrl = url;
    if (params) {
      const queryString = Object.keys(params).map((key) => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`).join("&");
      fullUrl += `?${queryString}`;
    }
    return this.request(fullUrl, { method: "GET", headers });
  }
  // POST请求
  async post(url, data, headers) {
    return this.request(url, { method: "POST", data, headers });
  }
  // PUT请求
  async put(url, data, headers) {
    return this.request(url, { method: "PUT", data, headers });
  }
  // DELETE请求
  async delete(url, headers) {
    return this.request(url, { method: "DELETE", headers });
  }
  // 设置基础URL
  setBaseURL(baseURL) {
    this.baseURL = baseURL;
  }
  // 设置超时时间
  setTimeout(timeout) {
    this.timeout = timeout;
  }
  // 登录成功后设置token
  setAuthToken(token) {
    this.setToken(token);
  }
  // 登出时清除token
  clearAuthToken() {
    this.clearToken();
  }
}
const request = new RequestService();
exports.request = request;

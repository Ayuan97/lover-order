"use strict";
const common_vendor = require("../common/vendor.js");
const api_request = require("./request.js");
const api_config = require("./config.js");
class AuthService {
  // 微信登录
  static async wechatLogin(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.AUTH.WECHAT_LOGIN, params);
    console.log("完整响应:", response);
    console.log("登录响应数据:", response.data);
    const loginData = response.data.data;
    console.log("实际登录数据:", loginData);
    if (loginData.token) {
      api_request.request.setAuthToken(loginData.token);
      console.log("保存用户信息:", loginData.user);
      common_vendor.index.setStorageSync("user_info", loginData.user);
      common_vendor.index.setStorageSync("refresh_token", loginData.token);
    }
    return loginData;
  }
  // 刷新token
  static async refreshToken() {
    const refreshToken = common_vendor.index.getStorageSync("refresh_token");
    if (!refreshToken) {
      throw new Error("没有refresh token");
    }
    console.log("发送token刷新请求...");
    try {
      const response = await api_request.request.post(api_config.API_ENDPOINTS.AUTH.REFRESH_TOKEN, {
        token: refreshToken
      });
      console.log("Token刷新响应:", response);
      const tokenData = response.data.data;
      if (tokenData.token) {
        api_request.request.setAuthToken(tokenData.token);
        common_vendor.index.setStorageSync("refresh_token", tokenData.token);
        console.log("Token更新成功");
      }
      const currentUser = this.getCurrentUser();
      return {
        token: tokenData.token,
        user: currentUser || {
          id: 0,
          openid: "",
          nickname: "",
          avatar: "",
          gender: 0,
          role: "member",
          is_active: true,
          created_at: "",
          updated_at: ""
        }
      };
    } catch (error) {
      console.error("Token刷新请求失败:", error);
      if (error.data && error.data.error && error.data.error.includes("token not ready for refresh")) {
        throw new Error("token not ready for refresh");
      }
      if (error.message && error.message.includes("token not ready for refresh")) {
        throw new Error("token not ready for refresh");
      }
      throw error;
    }
  }
  // 登出
  static async logout() {
    try {
      await api_request.request.post(api_config.API_ENDPOINTS.AUTH.LOGOUT);
    } catch (error) {
      console.error("登出请求失败:", error);
    } finally {
      api_request.request.clearAuthToken();
      common_vendor.index.removeStorageSync("user_info");
      common_vendor.index.removeStorageSync("refresh_token");
    }
  }
  // 获取用户信息
  static async getUserProfile() {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.USER.PROFILE);
    return response.data.data;
  }
  // 更新用户信息
  static async updateUserProfile(params) {
    const response = await api_request.request.put(api_config.API_ENDPOINTS.USER.PROFILE, params);
    const userData = response.data.data;
    common_vendor.index.setStorageSync("user_info", userData);
    return userData;
  }
  // 检查登录状态（仅检查本地存储，不验证token有效性）
  static isLoggedIn() {
    const token = common_vendor.index.getStorageSync("token");
    const userInfo = common_vendor.index.getStorageSync("user_info");
    return !!(token && userInfo);
  }
  // 获取当前用户信息
  static getCurrentUser() {
    try {
      return common_vendor.index.getStorageSync("user_info");
    } catch (error) {
      return null;
    }
  }
  // 微信登录（小程序专用）- 按照官方推荐流程
  static async wechatMiniLogin() {
    return new Promise((resolve, reject) => {
      common_vendor.index.login({
        provider: "weixin",
        success: async (loginRes) => {
          try {
            if (!loginRes.code) {
              throw new Error("获取微信登录code失败");
            }
            const result = await this.wechatLogin({
              code: loginRes.code
            });
            resolve(result);
          } catch (error) {
            reject(error);
          }
        },
        fail: (error) => {
          reject(new Error("微信登录失败: " + error.errMsg));
        }
      });
    });
  }
  // 获取用户信息（独立的步骤，可选）
  static async getUserInfo() {
    return new Promise((resolve, reject) => {
      common_vendor.index.getUserProfile({
        desc: "用于完善用户资料",
        success: (userRes) => {
          resolve({
            nickname: userRes.userInfo.nickName,
            avatar_url: userRes.userInfo.avatarUrl,
            gender: userRes.userInfo.gender
          });
        },
        fail: (error) => {
          reject(new Error("获取用户信息失败: " + error.errMsg));
        }
      });
    });
  }
  // 完整登录流程（登录 + 获取用户信息）
  static async wechatMiniLoginWithUserInfo() {
    return new Promise((resolve, reject) => {
      common_vendor.index.getUserProfile({
        desc: "用于完善用户资料",
        success: async (userRes) => {
          try {
            common_vendor.index.login({
              provider: "weixin",
              success: async (loginRes) => {
                try {
                  if (!loginRes.code) {
                    throw new Error("获取微信登录code失败");
                  }
                  const result = await this.wechatLogin({
                    code: loginRes.code,
                    user_info: {
                      nickname: userRes.userInfo.nickName,
                      avatar_url: userRes.userInfo.avatarUrl,
                      gender: userRes.userInfo.gender
                    }
                  });
                  resolve(result);
                } catch (error) {
                  reject(error);
                }
              },
              fail: (error) => {
                reject(new Error("微信登录失败: " + error.errMsg));
              }
            });
          } catch (error) {
            reject(error);
          }
        },
        fail: (error) => {
          reject(new Error("获取用户信息失败: " + error.errMsg));
        }
      });
    });
  }
  // 简化版微信登录（不获取用户详细信息）
  static async wechatMiniLoginSimple() {
    return new Promise((resolve, reject) => {
      common_vendor.index.login({
        provider: "weixin",
        success: async (loginRes) => {
          try {
            if (!loginRes.code) {
              throw new Error("获取微信登录code失败");
            }
            const result = await this.wechatLogin({
              code: loginRes.code
            });
            resolve(result);
          } catch (error) {
            reject(error);
          }
        },
        fail: (error) => {
          reject(new Error("微信登录失败: " + error.errMsg));
        }
      });
    });
  }
  // 静默登录（使用已有的code）
  static async silentLogin() {
    return new Promise((resolve, reject) => {
      common_vendor.index.login({
        provider: "weixin",
        success: async (loginRes) => {
          try {
            if (!loginRes.code) {
              throw new Error("获取微信登录code失败");
            }
            const result = await this.wechatLogin({
              code: loginRes.code
            });
            resolve(result);
          } catch (error) {
            reject(error);
          }
        },
        fail: (error) => {
          reject(new Error("微信登录失败: " + error.errMsg));
        }
      });
    });
  }
}
exports.AuthService = AuthService;

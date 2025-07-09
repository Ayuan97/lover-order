"use strict";
const common_vendor = require("../common/vendor.js");
const api_request = require("./request.js");
const api_config = require("./config.js");
class FamilyService {
  // 创建家庭
  static async createFamily(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.FAMILY.CREATE, params);
    return response.data.data;
  }
  // 获取家庭信息
  static async getFamilyInfo() {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.FAMILY.INFO);
    return response.data.data;
  }
  // 更新家庭信息
  static async updateFamilyInfo(params) {
    const response = await api_request.request.put(api_config.API_ENDPOINTS.FAMILY.UPDATE, params);
    return response.data.data;
  }
  // 加入家庭
  static async joinFamily(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.FAMILY.JOIN, params);
    return response.data.data;
  }
  // 退出家庭
  static async leaveFamily() {
    await api_request.request.post(api_config.API_ENDPOINTS.FAMILY.LEAVE);
  }
  // 删除家庭
  static async deleteFamily() {
    await api_request.request.delete(api_config.API_ENDPOINTS.FAMILY.DELETE);
  }
  // 获取家庭成员列表
  static async getFamilyMembers(includeGuests = false) {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.USER.FAMILY_MEMBERS, {
      include_guests: includeGuests
    });
    return response.data.data;
  }
  // 获取家庭统计信息
  static async getFamilyStats() {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.FAMILY.STATS);
    return response.data.data;
  }
  // 检查用户是否有家庭
  static hasFamily() {
    try {
      const userInfo = common_vendor.index.getStorageSync("user_info");
      return !!(userInfo && userInfo.family_id);
    } catch (error) {
      return false;
    }
  }
  // 获取当前用户的家庭ID
  static getCurrentFamilyId() {
    try {
      const userInfo = common_vendor.index.getStorageSync("user_info");
      return (userInfo == null ? void 0 : userInfo.family_id) || null;
    } catch (error) {
      return null;
    }
  }
  // 创建访客邀请
  static async createGuestInvite(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.GUEST.INVITE, params);
    return response.data.data;
  }
  // 获取访客邀请列表
  static async getGuestInvites() {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.GUEST.INVITATIONS);
    return response.data.data;
  }
  // 检查访客邀请码
  static async checkGuestInvite(inviteCode) {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.GUEST.INVITE_CHECK, {
      invite_code: inviteCode
    });
    return response.data.data;
  }
  // 访客注册
  static async guestRegister(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.GUEST.REGISTER, params);
    return response.data.data;
  }
  // 生成分享链接
  static generateShareLink(inviteCode) {
    const baseUrl = "https://your-domain.com";
    return `${baseUrl}/guest?invite=${inviteCode}`;
  }
  // 生成分享文本
  static generateShareText(familyName, inviteCode) {
    return `🏠 ${familyName} 邀请您品尝美味家常菜！

📖 浏览精选菜谱
🛒 在线点餐服务
✨ 温馨家庭料理

邀请码：${inviteCode}

点击链接立即体验：${this.generateShareLink(inviteCode)}`;
  }
}
exports.FamilyService = FamilyService;

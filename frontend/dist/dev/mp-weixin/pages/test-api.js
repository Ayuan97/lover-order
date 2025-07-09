"use strict";
const common_vendor = require("../common/vendor.js");
const api_request = require("../api/request.js");
const api_recipe = require("../api/recipe.js");
const api_auth = require("../api/auth.js");
const api_config = require("../api/config.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "test-api",
  setup(__props) {
    const healthStatus = common_vendor.ref("");
    const healthResult = common_vendor.ref("未测试");
    const categoriesStatus = common_vendor.ref("");
    const categoriesResult = common_vendor.ref("未测试");
    const recipesStatus = common_vendor.ref("");
    const recipesResult = common_vendor.ref("未测试");
    const wechatStatus = common_vendor.ref("");
    const wechatResult = common_vendor.ref("未测试");
    const testData = common_vendor.ref(null);
    const testHealth = async () => {
      healthStatus.value = "loading";
      healthResult.value = "测试中...";
      try {
        const baseUrl = api_config.API_CONFIG.BASE_URL.replace("/api/v1", "");
        const response = await api_request.request.request(`${baseUrl}/health`);
        healthStatus.value = "success";
        healthResult.value = `成功: ${response.data.message}`;
        testData.value = response.data;
      } catch (error) {
        healthStatus.value = "error";
        healthResult.value = `失败: ${error.message}`;
        testData.value = error;
      }
    };
    const testCategories = async () => {
      categoriesStatus.value = "loading";
      categoriesResult.value = "测试中...";
      try {
        const categories = await api_recipe.CategoryService.getCategoryList();
        categoriesStatus.value = "success";
        categoriesResult.value = `成功: 获取到 ${categories.length} 个分类`;
        testData.value = categories;
      } catch (error) {
        categoriesStatus.value = "error";
        categoriesResult.value = `失败: ${error.message}`;
        testData.value = error;
      }
    };
    const testRecipes = async () => {
      recipesStatus.value = "loading";
      recipesResult.value = "测试中...";
      try {
        const result = await api_recipe.RecipeService.getRecipeList({ page: 1, page_size: 10 });
        recipesStatus.value = "success";
        recipesResult.value = `成功: 获取到 ${result.recipes.length} 个菜谱`;
        testData.value = result;
      } catch (error) {
        recipesStatus.value = "error";
        recipesResult.value = `失败: ${error.message}`;
        testData.value = error;
      }
    };
    const testWechatLogin = async () => {
      wechatStatus.value = "loading";
      wechatResult.value = "测试中...";
      try {
        const result = await api_auth.AuthService.wechatMiniLogin();
        wechatStatus.value = "success";
        wechatResult.value = `成功: 登录用户 OpenID ${result.user.openid.substring(0, 8)}...`;
        testData.value = result;
      } catch (error) {
        wechatStatus.value = "error";
        wechatResult.value = `失败: ${error.message}`;
        testData.value = error;
      }
    };
    const testGetUserInfo = async () => {
      try {
        const userInfo = await api_auth.AuthService.getUserInfo();
        common_vendor.index.showModal({
          title: "用户信息获取成功",
          content: `昵称: ${userInfo.nickname}
性别: ${userInfo.gender === 1 ? "男" : userInfo.gender === 2 ? "女" : "未知"}`,
          showCancel: false
        });
      } catch (error) {
        common_vendor.index.showModal({
          title: "获取用户信息失败",
          content: error.message,
          showCancel: false
        });
      }
    };
    const testGetUserProfile = async () => {
      try {
        if (!api_auth.AuthService.isLoggedIn()) {
          common_vendor.index.showToast({
            title: "请先登录",
            icon: "none"
          });
          return;
        }
        const userProfile = await api_auth.AuthService.getUserProfile();
        common_vendor.index.showModal({
          title: "用户资料获取成功",
          content: `ID: ${userProfile.id}
昵称: ${userProfile.nickname || "未设置"}
角色: ${userProfile.role}`,
          showCancel: false
        });
      } catch (error) {
        common_vendor.index.showModal({
          title: "获取用户资料失败",
          content: error.message,
          showCancel: false
        });
      }
    };
    return (_ctx, _cache) => {
      return common_vendor.e({
        a: common_vendor.o(testHealth),
        b: common_vendor.t(healthResult.value),
        c: healthStatus.value === "success" ? 1 : "",
        d: healthStatus.value === "error" ? 1 : "",
        e: common_vendor.o(testCategories),
        f: common_vendor.t(categoriesResult.value),
        g: categoriesStatus.value === "success" ? 1 : "",
        h: categoriesStatus.value === "error" ? 1 : "",
        i: common_vendor.o(testRecipes),
        j: common_vendor.t(recipesResult.value),
        k: recipesStatus.value === "success" ? 1 : "",
        l: recipesStatus.value === "error" ? 1 : "",
        m: common_vendor.o(testWechatLogin),
        n: common_vendor.t(wechatResult.value),
        o: wechatStatus.value === "success" ? 1 : "",
        p: wechatStatus.value === "error" ? 1 : "",
        q: common_vendor.o(testGetUserInfo),
        r: common_vendor.o(testGetUserProfile),
        s: testData.value
      }, testData.value ? {
        t: common_vendor.t(JSON.stringify(testData.value, null, 2))
      } : {});
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-9de77006"]]);
wx.createPage(MiniProgramPage);

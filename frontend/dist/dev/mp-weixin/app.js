"use strict";
Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
const common_vendor = require("./common/vendor.js");
const utils_auth = require("./utils/auth.js");
if (!Math) {
  "./pages/login/index.js";
  "./pages/index/index.js";
  "./pages/recipes/index.js";
  "./pages/orders/index.js";
  "./pages/profile/index.js";
  "./pages/family/index.js";
  "./pages/guest/share.js";
  "./pages/guest/index.js";
  "./pages/demo/guest-flow.js";
  "./pages/test-api.js";
}
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "App",
  setup(__props) {
    common_vendor.onLaunch(async () => {
      console.log("App Launch");
      try {
        const isLoggedIn = await utils_auth.autoLoginCheck();
        console.log("自动登录检查结果:", isLoggedIn);
        if (!isLoggedIn) {
          common_vendor.index.reLaunch({
            url: "/pages/login/index"
          });
        }
      } catch (error) {
        console.error("应用启动登录检查失败:", error);
      }
    });
    common_vendor.onShow(() => {
      console.log("App Show");
      const pages = getCurrentPages();
      if (pages.length > 0) {
        const currentPage = pages[pages.length - 1];
        const currentPath = `/${currentPage.route}`;
        utils_auth.checkPageAccess(currentPath).catch((error) => {
          console.error("页面访问权限检查失败:", error);
        });
      }
    });
    common_vendor.onHide(() => {
      console.log("App Hide");
    });
    return (_ctx, _cache) => {
      return {};
    };
  }
});
function createApp() {
  const app = common_vendor.createSSRApp(_sfc_main);
  const pinia = common_vendor.createPinia();
  app.use(pinia);
  return {
    app,
    pinia
  };
}
createApp().app.mount("#app");
exports.createApp = createApp;

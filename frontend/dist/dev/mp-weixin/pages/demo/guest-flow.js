"use strict";
const common_vendor = require("../../common/vendor.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "guest-flow",
  setup(__props) {
    const currentStep = common_vendor.ref(1);
    const startDemo = () => {
      let step = 1;
      const timer = setInterval(() => {
        currentStep.value = step;
        step++;
        if (step > 5) {
          clearInterval(timer);
          common_vendor.index.showToast({
            title: "演示完成",
            icon: "success"
          });
        }
      }, 1e3);
      setTimeout(() => {
        common_vendor.index.navigateTo({
          url: "/pages/family/index"
        });
      }, 2e3);
    };
    const viewGuestPage = () => {
      const demoInviteCode = "DEMO123";
      common_vendor.index.navigateTo({
        url: `/pages/guest/index?invite=${demoInviteCode}`
      });
    };
    return (_ctx, _cache) => {
      return {
        a: currentStep.value >= 1 ? 1 : "",
        b: currentStep.value >= 2 ? 1 : "",
        c: currentStep.value >= 3 ? 1 : "",
        d: currentStep.value >= 4 ? 1 : "",
        e: currentStep.value >= 5 ? 1 : "",
        f: common_vendor.o(startDemo),
        g: common_vendor.o(viewGuestPage)
      };
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-b6f7b903"]]);
wx.createPage(MiniProgramPage);

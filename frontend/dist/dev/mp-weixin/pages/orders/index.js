"use strict";
const common_vendor = require("../../common/vendor.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const createOrder = () => {
      common_vendor.index.navigateTo({
        url: "/pages/orders/create"
      });
    };
    return (_ctx, _cache) => {
      return {
        a: common_vendor.o(createOrder)
      };
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-91c80870"]]);
wx.createPage(MiniProgramPage);

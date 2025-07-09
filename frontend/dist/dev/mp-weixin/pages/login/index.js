"use strict";
const common_vendor = require("../../common/vendor.js");
const api_auth = require("../../api/auth.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const isLoading = common_vendor.ref(false);
    const handleWechatLogin = async () => {
      if (isLoading.value) return;
      isLoading.value = true;
      try {
        let result;
        try {
          result = await api_auth.AuthService.wechatMiniLoginWithUserInfo();
        } catch (error) {
          console.log("完整登录失败，尝试简化登录:", error.message);
          if (error.message.includes("getUserProfile") || error.message.includes("用户拒绝") || error.message.includes("user deny")) {
            common_vendor.index.showToast({
              title: "使用简化登录模式",
              icon: "none"
            });
            result = await api_auth.AuthService.wechatMiniLogin();
          } else {
            throw error;
          }
        }
        common_vendor.index.showToast({
          title: "登录成功",
          icon: "success"
        });
        setTimeout(() => {
          common_vendor.index.switchTab({
            url: "/pages/index/index"
          });
        }, 1500);
      } catch (error) {
        console.error("登录失败:", error);
        let errorMessage = "登录过程中出现错误，请重试";
        if (error.message.includes("网络")) {
          errorMessage = "网络连接失败，请检查网络设置";
        } else if (error.message.includes("code")) {
          errorMessage = "微信登录授权失败，请重试";
        } else if (error.message.includes("40029")) {
          errorMessage = "登录凭证无效，请重试";
        }
        common_vendor.index.showModal({
          title: "登录失败",
          content: errorMessage,
          showCancel: true,
          cancelText: "取消",
          confirmText: "重试",
          success: (res) => {
            if (res.confirm) {
              setTimeout(() => {
                handleWechatLogin();
              }, 500);
            }
          }
        });
      } finally {
        isLoading.value = false;
      }
    };
    const showPrivacyPolicy = () => {
      common_vendor.index.showModal({
        title: "隐私政策",
        content: "我们重视您的隐私保护，详细的隐私政策请访问我们的官网查看。",
        showCancel: false
      });
    };
    const showUserAgreement = () => {
      common_vendor.index.showModal({
        title: "用户协议",
        content: "使用本应用即表示您同意我们的用户协议，详细内容请访问官网查看。",
        showCancel: false
      });
    };
    return (_ctx, _cache) => {
      return common_vendor.e({
        a: !isLoading.value
      }, !isLoading.value ? {} : {}, {
        b: common_vendor.t(isLoading.value ? "登录中..." : "微信授权登录"),
        c: isLoading.value ? 1 : "",
        d: isLoading.value,
        e: common_vendor.o(handleWechatLogin),
        f: common_vendor.o(showPrivacyPolicy),
        g: common_vendor.o(showUserAgreement)
      });
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-45258083"]]);
wx.createPage(MiniProgramPage);

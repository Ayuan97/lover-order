"use strict";
const common_vendor = require("../../common/vendor.js");
const api_recipe = require("../../api/recipe.js");
const api_family = require("../../api/family.js");
const _sfc_main = /* @__PURE__ */ common_vendor.defineComponent({
  __name: "index",
  setup(__props) {
    const isPageLoading = common_vendor.ref(true);
    const hasFamily = common_vendor.ref(false);
    const merchantInfo = common_vendor.ref({
      name: "温馨家庭厨房",
      description: "用心烹饪，温暖每一餐",
      rating: 4.8,
      reviewCount: 128,
      monthlySales: 128,
      minOrder: 0,
      deliveryFee: 0,
      deliveryTime: 30,
      logo: "",
      backgroundImage: ""
    });
    const recipes = common_vendor.ref([]);
    const categories = common_vendor.ref([]);
    const loading = common_vendor.ref(false);
    const activeCategory = common_vendor.ref(null);
    const scrollIntoView = common_vendor.ref("");
    const cartItems = common_vendor.ref([]);
    const defaultRecipeImage = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjAiIGhlaWdodD0iMTIwIiByeD0iMTIiIGZpbGw9IiNGNUY1RjUiLz4KPHRleHQgeD0iNjAiIHk9IjcwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfk5Y8L3RleHQ+Cjwvc3ZnPg==");
    const showBgModal = common_vendor.ref(false);
    const selectedBg = common_vendor.ref("");
    const familyAnnouncement = common_vendor.ref("🏠 欢迎来到温馨家庭厨房！今日推荐：红烧肉、宫保鸡丁，让我们一起享受美味时光~ ❤️");
    const scrollLeft = common_vendor.ref(0);
    const showAnnouncementModal = common_vendor.ref(false);
    const tempAnnouncement = common_vendor.ref("");
    const defaultBackgroundImage = common_vendor.ref("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjI0MCIgdmlld0JveD0iMCAwIDc1MCAyNDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojRkZGM0UwO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNGRkU0QjU7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIyNDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPCEtLSBUYWJsZSAtLT4KPHJlY3QgeD0iMjAwIiB5PSIxNDAiIHdpZHRoPSIzNTAiIGhlaWdodD0iODAiIHJ4PSI4IiBmaWxsPSIjRkY4QTY1IiBvcGFjaXR5PSIwLjgiLz4KPCEtLSBQb3QgLS0+CjxjaXJjbGUgY3g9IjM3NSIgY3k9IjEyMCIgcj0iNjAiIGZpbGw9IiM2NjY2NjYiLz4KPGNpcmNsZSBjeD0iMzc1IiBjeT0iMTEwIiByPSI1NSIgZmlsbD0iI0ZGRkZGRiIvPgo8IS0tIEZvb2QgaW4gcG90IC0tPgo8Y2lyY2xlIGN4PSIzNjAiIGN5PSIxMDAiIHI9IjgiIGZpbGw9IiNGRjY5NDciLz4KPGNpcmNsZSBjeD0iMzkwIiBjeT0iMTA1IiByPSI2IiBmaWxsPSIjNENBRjUwIi8+CjxjaXJjbGUgY3g9IjM3NSIgY3k9IjEyMCIgcj0iNSIgZmlsbD0iI0ZGQzEwNyIvPgo8IS0tIENhcnJvdCAtLT4KPHBhdGggZD0iTTEwMCAxNjBMMTIwIDEyMEwxNDAgMTYwWiIgZmlsbD0iI0ZGNjk0NyIvPgo8cGF0aCBkPSJNMTEwIDEyMEwxMTUgMTAwTDEyNSAxMjBaIiBmaWxsPSIjNENBRjUwIi8+CjwhLS0gTGVhZnkgZ3JlZW4gLS0+CjxwYXRoIGQ9Ik02MDAgMTAwUTYyMCA4MCA2NDAgMTAwUTYyMCAxMjAgNjAwIDEwMFoiIGZpbGw9IiM0Q0FGNTQiLz4KPCEtLSBDaGVmIGhhdCAtLT4KPHJlY3QgeD0iNTAwIiB5PSI2MCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjQwIiByeD0iMjAiIGZpbGw9IiNGRkZGRkYiLz4KPHJlY3QgeD0iNTEwIiB5PSI0MCIgd2lkdGg9IjYwIiBoZWlnaHQ9IjMwIiByeD0iMTUiIGZpbGw9IiNGRkZGRkYiLz4KPC9zdmc+");
    const backgroundOptions = common_vendor.ref([
      {
        id: 1,
        name: "温馨橙色",
        url: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojRkY4QTY1O3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNGRjcwNDM7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMTUwIiBjeT0iMTAwIiByPSI0MCIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjEpIi8+CjxjaXJjbGUgY3g9IjYwMCIgY3k9IjIwMCIgcj0iNjAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4wOCkiLz4KPGNpcmNsZSBjeD0iNDAwIiBjeT0iNTAiIHI9IjMwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTIpIi8+Cjx0ZXh0IHg9IjM3NSIgeT0iMTYwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4zKSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+NsO+4jzwvdGV4dD4KPC9zdmc+"
      },
      {
        id: 2,
        name: "清新绿色",
        url: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojNjZCQjZBO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM0Q0FGNTQ7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMjAwIiBjeT0iODAiIHI9IjM1IiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTUpIi8+CjxjaXJjbGUgY3g9IjU1MCIgY3k9IjE4MCIgcj0iNTAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4xKSIvPgo8Y2lyY2xlIGN4PSIzNTAiIGN5PSI2MCIgcj0iMjUiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4yKSIvPgo8dGV4dCB4PSIzNzUiIHk9IjE2MCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjQwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuNCkiIHRleHQtYW5jaG9yPSJtaWRkbGUiPvCfjbXwn42FPC90ZXh0Pgo8L3N2Zz4="
      },
      {
        id: 3,
        name: "浪漫粉色",
        url: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojRkY4QTgwO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiNGRjUwNzI7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMTgwIiBjeT0iMTIwIiByPSI0NSIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjEyKSIvPgo8Y2lyY2xlIGN4PSI1ODAiIGN5PSIxNjAiIHI9IjU1IiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMDgpIi8+CjxjaXJjbGUgY3g9IjQyMCIgY3k9IjcwIiByPSIzNSIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjE1KSIvPgo8dGV4dCB4PSIzNzUiIHk9IjE2MCIgZm9udC1mYW1pbHk9IkFyaWFsIiBmb250LXNpemU9IjQwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMzUpIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIj7wn5GOXG4g8J+SljwvdGV4dD4KPC9zdmc+"
      },
      {
        id: 4,
        name: "优雅紫色",
        url: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNzUwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDc1MCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxkZWZzPgo8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQiIHgxPSIwJSIgeTE9IjAlIiB4Mj0iMTAwJSIgeTI9IjEwMCUiPgo8c3RvcCBvZmZzZXQ9IjAlIiBzdHlsZT0ic3RvcC1jb2xvcjojOUM4OEZGO3N0b3Atb3BhY2l0eToxIiAvPgo8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM3QzRERkY7c3RvcC1vcGFjaXR5OjEiIC8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPHJlY3Qgd2lkdGg9Ijc1MCIgaGVpZ2h0PSIzMDAiIGZpbGw9InVybCgjZ3JhZCkiLz4KPGNpcmNsZSBjeD0iMTYwIiBjeT0iOTAiIHI9IjQwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTQpIi8+CjxjaXJjbGUgY3g9IjU2MCIgY3k9IjE5MCIgcj0iNjAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4wOSkiLz4KPGNpcmNsZSBjeD0iMzgwIiBjeT0iNDAiIHI9IjMwIiBmaWxsPSJyZ2JhKDI1NSwyNTUsMjU1LDAuMTgpIi8+Cjx0ZXh0IHg9IjM3NSIgeT0iMTYwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iNDAiIGZpbGw9InJnYmEoMjU1LDI1NSwyNTUsMC4zKSIgdGV4dC1hbmNob3I9Im1pZGRsZSI+8J+MuO+4jzwvdGV4dD4KPC9zdmc+"
      }
    ]);
    const goToFamily = () => {
      common_vendor.index.navigateTo({
        url: "/pages/family/index"
      });
    };
    const loadCategories = async () => {
      try {
        console.log("开始加载分类...");
        console.log("API地址:", "http://192.168.4.15:8081/api/v1/dev/categories");
        const result = await api_recipe.CategoryService.getCategoryList();
        console.log("分类加载成功:", result);
        console.log("分类数量:", (result == null ? void 0 : result.length) || 0);
        categories.value = result || [];
      } catch (error) {
        console.error("加载分类失败:", error);
        console.error("错误详情:", error.message, error.statusCode);
        categories.value = [];
      }
    };
    const loadRecipes = async () => {
      var _a;
      try {
        console.log("开始加载菜谱...");
        console.log("API地址:", "http://192.168.4.15:8081/api/v1/dev/recipes");
        const result = await api_recipe.RecipeService.getRecipeList({
          page: 1,
          page_size: 100
        });
        console.log("菜谱加载成功:", result);
        console.log("菜谱数量:", ((_a = result.recipes) == null ? void 0 : _a.length) || 0);
        recipes.value = result.recipes || [];
      } catch (error) {
        console.error("加载菜谱失败:", error);
        console.error("错误详情:", error.message, error.statusCode);
        if (error.statusCode === 403 || error.statusCode === 400) {
          console.log("用户没有菜谱访问权限或请求参数错误，设置空菜谱列表");
          recipes.value = [];
        } else {
          console.log("其他错误，设置空菜谱列表");
          recipes.value = [];
        }
      }
    };
    const initData = async () => {
      loading.value = true;
      try {
        console.log("开始并行加载分类和菜谱...");
        const [categoriesResult, recipesResult] = await Promise.allSettled([
          loadCategories(),
          loadRecipes()
        ]);
        if (categoriesResult.status === "rejected") {
          console.error("加载分类失败:", categoriesResult.reason);
        }
        if (recipesResult.status === "rejected") {
          console.error("加载菜谱失败:", recipesResult.reason);
        }
        console.log("数据加载完成");
      } catch (error) {
        console.error("初始化数据失败:", error);
      } finally {
        loading.value = false;
      }
    };
    const checkFamilyStatus = async () => {
      try {
        console.log("开始检查家庭状态...");
        hasFamily.value = api_family.FamilyService.hasFamily();
        console.log("家庭状态检查结果:", hasFamily.value);
        const userInfo = common_vendor.index.getStorageSync("user_info");
        console.log("用户信息:", userInfo);
        if (userInfo && userInfo.family_id) {
          console.log("用户有家庭ID:", userInfo.family_id);
          hasFamily.value = true;
        } else {
          console.log("用户没有家庭ID");
          hasFamily.value = false;
        }
      } catch (error) {
        console.error("检查家庭状态失败:", error);
        hasFamily.value = false;
      }
    };
    const filteredRecipes = common_vendor.computed(() => {
      if (!activeCategory.value) {
        return recipes.value;
      }
      return recipes.value.filter((recipe) => recipe.category_id === activeCategory.value);
    });
    const cartItemCount = common_vendor.computed(() => {
      return cartItems.value.reduce((total, item) => total + item.quantity, 0);
    });
    const totalCookingTime = common_vendor.computed(() => {
      return cartItems.value.reduce((total, item) => total + item.cooking_time * item.quantity, 0);
    });
    const selectCategory = (categoryId) => {
      activeCategory.value = categoryId;
      scrollIntoView.value = `category-${categoryId}`;
    };
    const getCategoryRecipeCount = (categoryId) => {
      return recipes.value.filter((recipe) => recipe.category_id === categoryId).length;
    };
    const getDifficultyText = (difficulty) => {
      const difficultyMap = {
        1: "简单",
        2: "中等",
        3: "困难"
      };
      return difficultyMap[difficulty] || "未知";
    };
    const viewRecipeDetail = (recipe) => {
      common_vendor.index.navigateTo({
        url: `/pages/recipes/detail?id=${recipe.id}`
      });
    };
    const addToCart = (recipe) => {
      const existingItem = cartItems.value.find((item) => item.id === recipe.id);
      if (existingItem) {
        existingItem.quantity += 1;
      } else {
        cartItems.value.push({
          ...recipe,
          quantity: 1
        });
      }
      common_vendor.index.showToast({
        title: "已加入订单",
        icon: "success",
        duration: 1e3
      });
    };
    const toggleCartDetail = () => {
      console.log("显示购物车详情");
    };
    const goToOrders = () => {
      common_vendor.index.navigateTo({
        url: "/pages/orders/index"
      });
    };
    const showBackgroundSettings = () => {
      selectedBg.value = merchantInfo.value.backgroundImage || defaultBackgroundImage.value;
      showBgModal.value = true;
    };
    const closeBgModal = () => {
      showBgModal.value = false;
    };
    const selectBackground = (bgUrl) => {
      selectedBg.value = bgUrl;
    };
    const confirmBackground = () => {
      merchantInfo.value.backgroundImage = selectedBg.value;
      common_vendor.index.setStorageSync("family_background", selectedBg.value);
      showBgModal.value = false;
      common_vendor.index.showToast({
        title: "背景已更新",
        icon: "success",
        duration: 1500
      });
    };
    const showQRCode = () => {
      common_vendor.index.showToast({
        title: "二维码功能开发中",
        icon: "none"
      });
    };
    const editAnnouncement = () => {
      tempAnnouncement.value = familyAnnouncement.value;
      showAnnouncementModal.value = true;
    };
    const closeAnnouncementModal = () => {
      showAnnouncementModal.value = false;
    };
    const confirmAnnouncement = () => {
      familyAnnouncement.value = tempAnnouncement.value;
      common_vendor.index.setStorageSync("family_announcement", tempAnnouncement.value);
      showAnnouncementModal.value = false;
      common_vendor.index.showToast({
        title: "公告已更新",
        icon: "success",
        duration: 1500
      });
    };
    const startAnnouncementScroll = () => {
      setInterval(() => {
        scrollLeft.value += 1;
        if (scrollLeft.value > 1e3) {
          scrollLeft.value = 0;
        }
      }, 50);
    };
    common_vendor.onMounted(async () => {
      try {
        console.log("首页开始初始化...");
        isPageLoading.value = true;
        console.log("检查家庭状态...");
        await checkFamilyStatus();
        console.log("家庭状态检查完成:", hasFamily.value);
        if (hasFamily.value) {
          console.log("开始加载数据...");
          await initData();
          console.log("数据加载完成");
          if (categories.value.length > 0) {
            activeCategory.value = categories.value[0].id;
          }
          const savedBackground = common_vendor.index.getStorageSync("family_background");
          if (savedBackground) {
            merchantInfo.value.backgroundImage = savedBackground;
          }
          const savedAnnouncement = common_vendor.index.getStorageSync("family_announcement");
          if (savedAnnouncement) {
            familyAnnouncement.value = savedAnnouncement;
          }
          startAnnouncementScroll();
        } else {
          console.log("用户没有家庭，跳过数据加载");
        }
      } catch (error) {
        console.error("页面初始化失败:", error);
        common_vendor.index.showToast({
          title: "页面加载失败",
          icon: "error"
        });
      } finally {
        console.log("设置页面加载完成");
        isPageLoading.value = false;
      }
    });
    return (_ctx, _cache) => {
      return common_vendor.e({
        a: isPageLoading.value
      }, isPageLoading.value ? {} : !hasFamily.value ? {
        c: common_vendor.o(goToFamily)
      } : common_vendor.e({
        d: merchantInfo.value.backgroundImage || defaultBackgroundImage.value,
        e: common_vendor.t(merchantInfo.value.name.charAt(0)),
        f: common_vendor.t(merchantInfo.value.name),
        g: common_vendor.t(recipes.value.length),
        h: common_vendor.t(categories.value.length),
        i: common_vendor.o(showQRCode),
        j: common_vendor.o(showBackgroundSettings),
        k: common_vendor.t(familyAnnouncement.value),
        l: scrollLeft.value,
        m: common_vendor.o(editAnnouncement),
        n: showBgModal.value
      }, showBgModal.value ? {
        o: common_vendor.o(closeBgModal),
        p: common_vendor.f(backgroundOptions.value, (bg, k0, i0) => {
          return {
            a: bg.url,
            b: common_vendor.t(bg.name),
            c: selectedBg.value === bg.url ? 1 : "",
            d: bg.id,
            e: common_vendor.o(($event) => selectBackground(bg.url), bg.id)
          };
        }),
        q: common_vendor.o(closeBgModal),
        r: common_vendor.o(confirmBackground),
        s: common_vendor.o(() => {
        }),
        t: common_vendor.o(closeBgModal)
      } : {}, {
        v: showAnnouncementModal.value
      }, showAnnouncementModal.value ? {
        w: common_vendor.o(closeAnnouncementModal),
        x: tempAnnouncement.value,
        y: common_vendor.o(($event) => tempAnnouncement.value = $event.detail.value),
        z: common_vendor.t(tempAnnouncement.value.length),
        A: common_vendor.o(closeAnnouncementModal),
        B: common_vendor.o(confirmAnnouncement),
        C: common_vendor.o(() => {
        }),
        D: common_vendor.o(closeAnnouncementModal)
      } : {}, {
        E: common_vendor.f(categories.value, (category, k0, i0) => {
          return common_vendor.e({
            a: common_vendor.t(category.name),
            b: getCategoryRecipeCount(category.id) > 0
          }, getCategoryRecipeCount(category.id) > 0 ? {
            c: common_vendor.t(getCategoryRecipeCount(category.id))
          } : {}, {
            d: activeCategory.value === category.id ? 1 : "",
            e: category.id,
            f: common_vendor.o(($event) => selectCategory(category.id), category.id)
          });
        }),
        F: filteredRecipes.value.length === 0
      }, filteredRecipes.value.length === 0 ? {} : {
        G: common_vendor.f(filteredRecipes.value, (recipe, k0, i0) => {
          return {
            a: recipe.image || defaultRecipeImage.value,
            b: common_vendor.t(recipe.name),
            c: common_vendor.t(recipe.description || "暂无描述"),
            d: common_vendor.t(recipe.cooking_time),
            e: common_vendor.t(getDifficultyText(recipe.difficulty)),
            f: common_vendor.o(($event) => addToCart(recipe), recipe.id),
            g: recipe.id,
            h: common_vendor.o(($event) => viewRecipeDetail(recipe), recipe.id)
          };
        })
      }, {
        H: scrollIntoView.value,
        I: cartItems.value.length > 0
      }, cartItems.value.length > 0 ? common_vendor.e({
        J: cartItemCount.value > 0
      }, cartItemCount.value > 0 ? {
        K: common_vendor.t(cartItemCount.value)
      } : {}, {
        L: common_vendor.t(cartItemCount.value),
        M: common_vendor.t(totalCookingTime.value),
        N: common_vendor.o(toggleCartDetail),
        O: common_vendor.o(goToOrders)
      }) : {}), {
        b: !hasFamily.value
      });
    };
  }
});
const MiniProgramPage = /* @__PURE__ */ common_vendor._export_sfc(_sfc_main, [["__scopeId", "data-v-83a5a03c"]]);
wx.createPage(MiniProgramPage);

/// 应用名称到包名的映射，复用原Python项目配置
class AppPackages {
  static const Map<String, String> packages = {
    // 社交通讯
    '微信': 'com.tencent.mm',
    'WeChat': 'com.tencent.mm',
    'wechat': 'com.tencent.mm',
    'QQ': 'com.tencent.mobileqq',
    '微博': 'com.sina.weibo',
    
    // 电商
    '淘宝': 'com.taobao.taobao',
    '京东': 'com.jingdong.app.mall',
    '拼多多': 'com.xunmeng.pinduoduo',
    
    // 生活社交
    '小红书': 'com.xingin.xhs',
    '豆瓣': 'com.douban.frodo',
    '知乎': 'com.zhihu.android',
    
    // 地图导航
    '高德地图': 'com.autonavi.minimap',
    '百度地图': 'com.baidu.BaiduMap',
    
    // 美食服务
    '美团': 'com.sankuai.meituan',
    '大众点评': 'com.dianping.v1',
    '饿了么': 'me.ele',
    '肯德基': 'com.yek.android.kfc.activitys',
    
    // 旅行出行
    '携程': 'ctrip.android.view',
    '铁路12306': 'com.MobileTicket',
    '12306': 'com.MobileTicket',
    '去哪儿': 'com.Qunar',
    '去哪儿旅行': 'com.Qunar',
    '滴滴出行': 'com.sdu.did.psnger',
    
    // 视频娱乐
    'bilibili': 'tv.danmaku.bili',
    '抖音': 'com.ss.android.ugc.aweme',
    '快手': 'com.smile.gifmaker',
    '腾讯视频': 'com.tencent.qqlive',
    '爱奇艺': 'com.qiyi.video',
    '优酷视频': 'com.youku.phone',
    '芒果TV': 'com.hunantv.imgo.activity',
    
    // 音乐
    '网易云音乐': 'com.netease.cloudmusic',
    'QQ音乐': 'com.tencent.qqmusic',
    '汽水音乐': 'com.luna.music',
    '喜马拉雅': 'com.ximalaya.ting.android',
    
    // 阅读
    '番茄小说': 'com.dragon.read',
    '番茄免费小说': 'com.dragon.read',
    '七猫免费小说': 'com.kmxs.reader',
    
    // 办公
    '飞书': 'com.ss.android.lark',
    'QQ邮箱': 'com.tencent.androidqqmail',
    
    // AI工具
    '豆包': 'com.larus.nova',
    
    // 健康健身
    'keep': 'com.gotokeep.keep',
    '美柚': 'com.lingan.seeyou',
    
    // 新闻资讯
    '腾讯新闻': 'com.tencent.news',
    '今日头条': 'com.ss.android.article.news',
    
    // 房产
    '贝壳找房': 'com.lianjia.beike',
    '安居客': 'com.anjuke.android.app',
    
    // 金融
    '同花顺': 'com.hexin.plat.android',
    
    // 游戏
    '星穹铁道': 'com.miHoYo.hkrpg',
    '崩坏：星穹铁道': 'com.miHoYo.hkrpg',
    '恋与深空': 'com.papegames.lysk.cn',
    
    // 系统
    'Settings': 'com.android.settings',
    'AndroidSystemSettings': 'com.android.settings',
    'Chrome': 'com.android.chrome',
    'Google Chrome': 'com.android.chrome',
    'Clock': 'com.android.deskclock',
    'Contacts': 'com.android.contacts',
    
    // Google应用
    'Gmail': 'com.google.android.gm',
    'Google Maps': 'com.google.android.apps.maps',
    'Google Drive': 'com.google.android.apps.docs',
    'Google Calendar': 'com.google.android.calendar',
    
    // 其他常用
    'Telegram': 'org.telegram.messenger',
    'WhatsApp': 'com.whatsapp',
    'Twitter': 'com.twitter.android',
    'X': 'com.twitter.android',
    'Reddit': 'com.reddit.frontpage',
    'TikTok': 'com.zhiliaoapp.musically',
    'Temu': 'com.einnovation.temu',
  };

  /// 根据应用名获取包名
  static String? getPackageName(String appName) {
    return packages[appName];
  }

  /// 根据包名获取应用名
  static String? getAppName(String packageName) {
    for (final entry in packages.entries) {
      if (entry.value == packageName) {
        return entry.key;
      }
    }
    return null;
  }

  /// 获取所有支持的应用名称列表
  static List<String> get supportedApps => packages.keys.toList();

  /// 检查应用是否受支持
  static bool isSupported(String appName) => packages.containsKey(appName);
}

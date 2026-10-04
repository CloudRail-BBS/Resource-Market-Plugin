# Discourse 资源中心（Resource Hub）

一个面向 Discourse 的资源中心插件：上传文件、下载社区共享的成品，并关联 GitHub
仓库，让仓库的 star、issue 和发布版本保持同步。

## 功能

- **上传** —— 拖放文件，按扩展名与体积双重白名单校验。
- **下载** —— 下载接口会统计下载次数，并返回文件的绝对地址。
- **GitHub 集成** —— 搜索 GitHub、关联仓库，导入元数据（star、fork、issue、
  语言、许可证）以及发布版本与版本附件，并由定时任务保持更新。
- **分类与标签** —— 内置种子分类，另有自由填写的标签，可在工具栏筛选。
- **评论** —— 支持 Markdown，经 `PrettyText` 渲染后再入库，因此存进去的 HTML
  在到达浏览器前就已消毒。
- **审核** —— 不在「自动通过」用户组内的成员，其提交会保持待审核，直到管理员
  通过。

## 要求

Discourse **3.4.0** 或更高版本。前端全部使用 `.gjs` 单文件组件编写；2026.7 ESR
之后 `.hbs` 模板已被移除，因此本插件不使用 `.hbs`。

## 安装

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/CloudRail-BBS/Resource-Market-Plugin.git discourse-resource-hub
```

然后重建：

```bash
./launcher rebuild app
```

本地开发：

```bash
cd plugins
git clone https://github.com/CloudRail-BBS/Resource-Market-Plugin.git discourse-resource-hub
```

然后重启 `bin/ember-cli -u`。

> **克隆的目标目录不能省略。** Discourse 按 `plugins/` 下的**目录名**识别插件，
> 该目录名必须等于 `plugin.rb` 里的 `# name:` —— 也就是 `discourse-resource-hub`。
> 而本仓库的名字是 `Resource-Market-Plugin`，直接执行
> `git clone https://github.com/CloudRail-BBS/Resource-Market-Plugin.git`
> 会得到 `plugins/Resource-Market-Plugin/`，插件会**静默加载失败**。请始终像上面
> 那样带上结尾的目标目录。

> **另外：`./launcher rebuild app` 不会更新插件。** `after_code` 钩子执行的是
> `git clone`，而目标目录一旦存在，clone 就会失败、什么都不会拉取，于是你会用
> 旧代码重新编译一遍。更新时请先拉取：
>
> ```bash
> cd /var/discourse/plugins/discourse-resource-hub && git pull
> cd /var/discourse && ./launcher rebuild app
> ```

## 配置

所有设置位于 **后台 → 设置 → 插件**。

| 设置 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `resource_hub_enabled` | boolean | `true` | 总开关。 |
| `resource_hub_nav_link` | boolean | `true` | 在站点导航中显示入口。 |
| `resource_hub_title` | string | `资源中心` | 页面顶部标题。 |
| `resource_hub_description` | string | — | 标题下方的副标题。 |
| `resource_hub_max_file_size_kb` | integer | `20480` | 单个文件的最大体积（KB）。 |
| `resource_hub_authorized_extensions` | string | 压缩包、文档、图片、媒体等 | 附加白名单，见下方说明。 |
| `resource_hub_count_downloads` | boolean | `true` | 通过资源中心接口提供下载，以便计数。 |
| `resource_hub_upload_allowed_groups` | group list | *（任意已登录用户）* | 谁可以上传。 |
| `resource_hub_auto_approve_groups` | group list | `staff` | 谁无需审核即可发布。 |
| `resource_hub_github_enabled` | boolean | `true` | 启用 GitHub 集成。 |
| `resource_hub_github_token` | string（密文） | — | 只读令牌，把 API 限额从 60 次/小时提升到 5000 次/小时。 |
| `resource_hub_github_sync_hours` | integer | `6` | 后台同步间隔（`0` 表示关闭）。 |
| `resource_hub_github_import_releases` | boolean | `true` | 同步时导入发布版本的附件。 |
| `resource_hub_github_max_releases` | integer | `5` | 每次同步、每个仓库导入多少个发布版本。 |
| `resource_hub_github_topics` | string | `discourse-plugin\|discourse-theme\|discourse` | 导入仓库时保留的仓库标签。 |

> 已经保存过的站点设置**不会**被新的默认值覆盖。升级后如果想让新的中文默认值
> 生效，需要在后台把 `resource_hub_title` 和 `resource_hub_description` 重置。

### 上传：是两份白名单，不是一份

Discourse 会先用**核心**的 `authorized_extensions` 设置校验每一次上传，凡是
不在其中的，在插件控制器运行**之前**就被拒绝。而
`resource_hub_authorized_extensions` 是在此**之上**的**额外**限制：一次上传必须
同时满足两者。

本插件刻意**不会**在启动时改写站点级的 `authorized_extensions` 设置，因为那会
悄悄放宽论坛上所有其他上传路径。取而代之的是，启动时会记录一条警告，列出
「资源中心允许、但核心不允许」的扩展名：

```
[discourse-resource-hub] These extensions are allowed by the Resource Hub but not by
SiteSetting.authorized_extensions, so uploads of those types will be rejected by
Discourse core: 7z, rar. Add them under Admin → Settings → Files, or remove them from
`resource_hub_authorized_extensions`.
```

要分发可执行文件或安装包，需要**同时**放宽这两处设置。

### 关于 GitHub 令牌

未鉴权的 GitHub API 调用限制为**每 IP 每小时 60 次**，一个活跃的论坛很快就会
耗尽。请创建一个只读的个人访问令牌（经典令牌无需任何 scope；细粒度令牌只需
*Public repositories → read*），然后填入 `resource_hub_github_token`。

## 语言（i18n）

界面文案使用中文，同时提供 `en` 与 `zh_CN` 两套语言文件。

需要注意：Discourse 只加载与站点当前语言**匹配**的那套文件。如果只提供
`zh_CN`，那么语言设为英文的论坛仍会显示英文文案（甚至原始键名）。因此目前
`en` 这套兜底文件也填入了同样的中文，这样无论站点当前是什么语言，资源中心
都会显示中文。

需要重新支持英文时，把 `config/locales/*.en.yml` 换回英文即可（英文版本可从
git 历史中取回）。两种语言的**键名必须完全一致**，缺失的键会回退到 `en`。

## 架构

```
discourse-resource-hub/
├── plugin.rb                       # 清单 + 启动后注册
├── app/                            # 由 Zeitwerk 自动加载：绝不能 require_relative
│   ├── controllers/discourse_resource_hub/
│   │   ├── pages_controller.rb       # 为直接访问提供 SPA 外壳
│   │   ├── resources_controller.rb   # index/show/create/update/review/destroy/download
│   │   ├── comments_controller.rb
│   │   └── github_controller.rb      # search/show/link/sync/unlink
│   ├── jobs/scheduled/discourse_resource_hub/sync_github_repos.rb
│   ├── models/discourse_resource_hub/{resource,category,comment}.rb
│   ├── serializers/discourse_resource_hub/{resource,category,comment}_serializer.rb
│   └── views/discourse_resource_hub/pages/index.html.erb
├── assets/
│   ├── javascripts/discourse/
│   │   ├── api-initializers/init-resource-hub.js
│   │   ├── components/            # resource-hub-{card,uploader,github-picker}.gjs
│   │   ├── controllers/resource-hub/{index,new,show}.js
│   │   ├── routes/resource-hub.js # 父级（透传）
│   │   ├── routes/resource-hub/{index,new,show}.js
│   │   ├── templates/resource-hub.gjs        # 父级，渲染 {{outlet}}
│   │   ├── templates/resource-hub/{index,new,show}.gjs
│   │   └── resource-hub-route-map.js
│   └── stylesheets/resource-hub.scss
├── config/
│   ├── routes.rb                   # engine 自身路由 + 挂载到 /resource-hub
│   ├── settings.yml
│   └── locales/{server,client}.{en,zh_CN}.yml
├── db/migrate/                     # resources、categories、comments 与分类种子
├── lib/discourse_resource_hub/     # 由 plugin.rb 显式 require
│   ├── engine.rb                   # Rails::Engine + Zeitwerk 自动加载
│   ├── extensions.rb               # 扩展名白名单诊断
│   ├── github_client.rb            # GitHub REST 封装、缓存与错误映射
│   ├── github_sync.rb              # 把 GitHub 数据映射到 Resource 记录
│   └── guardian.rb                 # 上传 / 审核权限策略
└── spec/                           # RSpec：模型、lib、请求
```

`app/` 由 Zeitwerk 接管，**从不**用 `require_relative`；`lib/` 不会被自动加载，
因此**必须**显式 require。两者混用会让 Zeitwerk 和显式 require 争夺同一批常量
并导致整个启动失败，所以 `lib/` 被刻意排除在 `config.autoload_paths` 之外。
代价是修改 `lib/` 下的代码需要重启服务，而不是热重载。

### 路由：三条极易踩错的规则

Ember 路由是本插件最容易「静默失效」的部分，因此在这里写清楚。

**1. 顶层 route map 必须导出函数，而不是对象。**
`frontend/discourse/app/mapping-router.js` 会收集所有 `*-route-map.js`，并按
两种方式之一处理：

```js
if (typeof mapObj === "function") {
  tree.extract(mapObj);                       // 以路由树根作为 `this` 调用
} else {
  extras.push(mapObj);
}
// 稍后……
extras.forEach((extra) => {
  let node = tree.findPath(extra.resource);   // 查找一个已存在的节点
  if (node) { node.extract(extra.map); }      // ← 找不到即丢弃，不报错
});
```

也就是说，对象形式（`{ resource: "admin", map() {} }`）只能**挂载到已存在的节点**
上 —— 比如 `admin`、`user`。`resource-hub` 是一个全新的顶层路由，没有可挂载的
节点，若用对象形式会被**无声丢弃**：路由根本不存在，URL 落到兜底的 404。
因此本文件导出一个函数，与核心 `app/routes/app-route-map.js`、
discourse-cakeday 的 `/cakeday` 做法一致。

**2. 文件路径与路由名一一对应。** Ember 把 `a.b.c` 解析为 `routes/a/b/c.js`
—— 是嵌套目录，不是扁平的 `a-b-c.js`。父级路由也拥有自己的文件，且它的模板
必须渲染 `{{outlet}}`，否则子路由无处渲染、页面一片空白：

| 路由名 | 路由 | 控制器 | 模板 |
| --- | --- | --- | --- |
| `resource-hub` | `routes/resource-hub.js` | — | `templates/resource-hub.gjs`（内含 `{{outlet}}`） |
| `resource-hub.index` | `routes/resource-hub/index.js` | `controllers/resource-hub/index.js` | `templates/resource-hub/index.gjs` |
| `resource-hub.new` | `routes/resource-hub/new.js` | `controllers/resource-hub/new.js` | `templates/resource-hub/new.gjs` |
| `resource-hub.show` | `routes/resource-hub/show.js` | `controllers/resource-hub/show.js` | `templates/resource-hub/show.gjs` |

**3. 子路径是相对路径。** `{ path: "r/:slug" }` 写在 `resource-hub` 内部，解析为
`/resource-hub/r/:slug`，与 `config/routes.rb` 里的服务端路由一致。

**4. 导航项的 `name` 会变成 CSS class。** `NavigationItem` 会把 `content.name`
原样输出到生成的 `<li>` 上（`dConcatClass(..., this.content.name)`），所以名为
`resource-hub` 的导航项会生成 `<li class="... resource-hub">`，正好撞上本插件
自己的页面级 `.resource-hub` 规则 —— 而该规则含 `margin: 0 auto`，会吃掉导航栏
flex 行里的全部剩余空间，于是整个导航栏被撑大。现有两道防护：

- 导航项命名为 `resource-hub-link`，把两个命名空间分开；
- 页面根规则加限定符写成 `div.resource-hub`，因此它永远只能匹配页面容器，
  不可能匹配到 `<li>`。

**5. engine 的挂载必须写在 `config/routes.rb`，而且要用 `draw`。**

```ruby
# config/routes.rb
Discourse::Application.routes.draw do
  mount ::DiscourseResourceHub::Engine, at: "/resource-hub"
end
```

看起来更"安全"的写法其实是坏的：

```ruby
# plugin.rb —— 不要这样写，挂载永远不会生效
after_initialize do
  Discourse::Application.routes.append do
    mount ::DiscourseResourceHub::Engine, at: "/resource-hub"
  end
end
```

Rails 加载插件的 `config/routes.rb` 时，应用的路由表**还处于打开状态**；而
`after_initialize` 执行时路由表**已经终结**。`append` 注册的块只能由
`finalize!` 来执行，此时再也不会被调用——engine **静默地从未挂载**，
`/resource-hub` 下所有 URL 都会 404（"找不到请求的 URL 或资源"）。

注意：`discourse-cakeday` 确实用了 `append` 写法，但它能工作是因为它的导航入口
传的是 `route:`（Ember 路由名，客户端跳转），从不触发整页请求；本插件的顶栏入口
是普通 `<a href>`，点击就是整页跳转，必须由服务端接住。**不要照抄 cakeday 的挂载方式。**

至于 `draw` 会不会清空路由表：不会。此时 Rails 处于禁止清空的状态
（`@disable_clear_and_finalize`），官方 `discourse-data-explorer` 用的就是这个写法。

资源中心的入口通过 `addNavigationBarItem` 显示在顶部导航栏。

### 请求流程

1. `resource-hub-route-map.js` 在 Ember 路由中注册 `/resource-hub`。
2. 直接访问或刷新会命中 `PagesController`，它跳过 `check_xhr` 并渲染应用外壳；
   随后 Ember 启动并接管路由。
3. 数据一律来自 JSON API —— 例如 `GET /resource-hub/resources.json` 会分发到
   `ResourcesController#index`。
4. 控制器使用与核心一致的序列化基类（Discourse 会把当前的 `Guardian`
   作为序列化器的 `scope` 注入）。
5. Ember 渲染对应的 `.gjs` 模板。

#### 页面路由**不要**判断 `request.format`

`PagesController#index` 里只检查 `SiteSetting.resource_hub_enabled`，
**没有** `raise Discourse::NotFound unless request.format.html?` 这类格式判断。

Discourse 并非只用整页请求驱动页面路由：`ApplicationController` 带有
`before_action :preload_json` 与 `before_action :check_xhr`，Ember 也会用
JSON accept 的 XHR 请求即将渲染的路由。因此在 action 内部判断格式是错的 ——
一个完全正常的预加载 XHR 会带着 JSON accept 进来，判断失败、抛
`Discourse::NotFound`，页面就以「找不到请求的 URL 或资源」404。
它的**特征**很好认：响应头 `X-Discourse-Route` 指向**你自己的控制器**，
但状态码是 404，例如

```
X-Discourse-Route: discourse_resource_hub/pages/index
HTTP/1.1 404 Not Found
```

判断方法：同一个 URL 换 accept 头请求一次。

```
GET /resource-hub/  Accept: text/html   →  200     # 整页导航
GET /resource-hub/  JSON / 默认 accept  →  404     # Discourse 的预加载 XHR
```

要挡住 JSON 请求应该用 Discourse 的机制 `before_action :check_xhr`，
而页面路由则用 `skip_before_action :check_xhr, only: :index` 重新放行 ——
这也正是本插件采用的写法。官方插件（如 `discourse-data-explorer`）
同样不做任何 format 判断。

### API 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/resource-hub/resources.json` | `type`、`q`、`sort`、`category_id`、`topic`、`page`、`per_page`、`mine` |
| `GET` | `/resource-hub/resources/:id.json` | 接受 **slug 或**数字 id |
| `POST` | `/resource-hub/resources.json` | `upload_id` **或** `repo_url` |
| `PUT` | `/resource-hub/resources/:id.json` | 作者或管理员 |
| `PATCH` | `/resource-hub/resources/:id/review.json` | 仅管理员：`status=approved\|rejected` |
| `DELETE` | `/resource-hub/resources/:id.json` | 作者或管理员 |
| `POST` | `/resource-hub/resources/:id/download.json` | 返回 `redirect_url` |
| `GET`/`POST` | `/resource-hub/resources/:id/comments.json` | |
| `DELETE` | `/resource-hub/resources/:id/comments/:comment_id.json` | |
| `GET` | `/resource-hub/github/search.json?q=` | 需登录，有限流 |
| `GET` | `/resource-hub/github/repo.json?repo=owner/name` | |
| `POST` | `/resource-hub/github/repo.json` | 关联仓库 |
| `POST` | `/resource-hub/github/repo/sync.json` | 仅管理员 |
| `DELETE` | `/resource-hub/github/repo.json` | 解除关联 |

## 安全说明

- **上传**走 Discourse 自身的 `POST /uploads.json`，因此 CSRF 防护、`Upload`
  记录以及后续的存取行为与站内其他地方完全一致。资源中心还会在服务端二次校验
  扩展名与体积，并拒绝属于其他成员的 `upload_id`。
- **下载**从不接受调用方传入的 URL。仓库解析为其规范的 GitHub 地址；文件则通过
  `upload.url` 得到站内的绝对地址（见下方「存储：仅支持本地存储」）。
- **可见性** —— 待审核与已拒绝的资源只有作者和管理员可读取，评论等所有接口
  都遵循这一规则。
- **审核流转**仅限管理员，因此作者无法自己通过自己的提交。

### 存储：仅支持本地存储

本插件**只面向 Discourse 的本地存储**（未启用 S3 上传）。这是一个有意的范围约定，
因为 S3 专用的接口在本地存储上并不存在。

`Discourse.store.url_for` 与 `signed_url_for_path` **只定义在 `FileStore::S3Store`
上**。`FileStore::BaseStore` 里根本没有它们（也没有 `not_implemented` 兜底），
所以在使用本地存储的论坛上调用会直接抛 `NoMethodError`，接口报 500 —— 这正是
下载接口此前 500 的原因。

核心 `UploadsController#show` 会用 `Discourse.store.internal?` 分支来兼容两种后端。
本插件不采用这种做法：那会留下一条在目标环境**永远不会被执行、因而也永远无法被验证**
的代码路径。下载接口只走一条路：

```ruby
def local_download_url(upload)
  path = upload.url.to_s
  return path if path.start_with?("http")

  "#{Discourse.base_url}#{path}"
end
```

`upload.url` 就是 `UploadSerializer` 作为 `:url` 暴露的那个相对路径
（`/uploads/default/original/…`），补上站点主机名即可。

校验脚本会直接禁止代码中出现 S3 专用接口，而不是要求它们加守卫。
- **GitHub 相关接口全部要求登录**，因为它们消耗的是站点共享的 API 配额。搜索
  接口还额外按用户限流。
- **关联仓库**使用与上传相同的权限校验，并且拒绝接管已经属于他人资源的仓库。
- **评论**经 `PrettyText` 渲染，HTML 在入库前就已消毒。

## 开发

```bash
# Ruby 语法
find . -name '*.rb' -exec ruby -c {} \;

# Ruby 测试（在 Discourse 检出目录下，本仓库置于 plugins/）
bin/rspec plugins/discourse-resource-hub/spec
```

前端面向 Discourse 当前的 `main`，这意味着：

- 使用 `.gjs` 单文件组件（`class X { <template>…</template> }`）。
- 路由模板使用 `ember-route-template` 的 `RouteTemplate`。
- 从 `discourse/ui-kit/d-button`、`discourse/ui-kit/helpers/d-icon` 和
  `discourse/truth-helpers` 导入（ui-kit 整合后核心使用的路径）。较旧的
  `discourse/components/…` 路径仍可通过兼容层解析。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。

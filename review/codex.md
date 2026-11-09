## Latency (ranked)

完整读取了 `src/` 的 10 个文件，共 2,034 行；未修改文件、未注入按键。以下按预期收益／工作量排序。`measured` 指 brief 提供的数据；优化收益均为 `estimate`，不能相加。未运行 App 或重新测量 Release；目录中没有构建配置或测试套件。

1. **缩略图逐张或小批更新，不要等待全部窗口捕获完成。**  
   **位置：** `src/WindowCapture.swift:85`、`src/WindowCapture.swift:93`、`src/AppDelegate.swift:122`。**预期收益：** 首张 fresh thumbnail 提前 `最后完成时间 − 首张完成时间`；全部完成时间基本不变，具体 ms 尚无分段数据。**工作量：M；风险：中；证据：estimate。**  
   当前 task group 收到图片后只存入字典，全部结束才更新 UI。优先提交选中窗口，再提交其余窗口，以 activation ID 和 window ID 校验更新；保留每轮最多 8 个任务。用 fake capture 控制完成顺序，验证首张可立即显示、旧 activation 不更新新面板。

2. **恢复最小化窗口时只查询、匹配一次 AX window。**  
   **位置：** `src/WindowActivator.swift:47`、`src/WindowActivator.swift:58`、`src/WindowActivator.swift:78`。**预期收益：** 最小化窗口 raise 约 **5–30 ms**；普通窗口约 **0 ms**。**工作量：S；风险：低至中；证据：estimate。**  
   `unminimize` 和 `raiseWindow` 分别读取同一个 app 的 `kAXWindows`，再逐个转换 window ID。合并为一次解析，依次执行 unminimize、raise、set-main。恢复后 AX element 是否仍有效属于 **estimate**；仅在明确失效时重新解析。fake 应验证成功路径只读一次窗口列表。

3. **捕获尺寸跟随实际 thumbnail 像素尺寸，而不是固定取原窗口的一半。**  
   **位置：** `src/WindowCapture.swift:106`、`src/SwitcherPanel.swift:99`、`src/ThumbnailView.swift:139`。**预期收益：** 减少图片内存和缩放工作；fresh capture 的 ms 收益待测，可能接近 0。**工作量：M；风险：中；证据：Apple docs + estimate。**  
   例如 2560×1440 的窗口目前输出 1280×720；满尺寸 cell 的图片区域是 284×190 points，在 2× 屏幕上按比例只需约 568×320 pixels，像素量减少约 **80%**。先计算 grid，再传入目标像素尺寸和 backing scale，保持宽高比。Apple 明确提供输出尺寸配置，但没有保证捕获耗时与像素量成比例。[SCStreamConfiguration](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)

4. **权限就绪后做一次有界预热，把首次枚举的初始化成本移出首次触发。**  
   **位置：** `src/WindowModel.swift:93`、`src/WindowModel.swift:116`、`src/WindowModel.swift:275`、`src/AppDelegate.swift:108`。**预期收益：** 冷枚举有 **142−24＝118 ms** 的已测冷热差可供验证；实际改善可能为 **0 ms**，预热完成后才可能接近 warm 路径。**工作量：M；风险：中；证据：measured 基线 + estimate 收益。**  
   目前只预热 icons，没有预热完整枚举。拆出不修改 MRU 的采集阶段，在后台预热一次；真实触发仍重新枚举，保证窗口集合新鲜。MRU 合并留在 main，不能直接把整个 `enumerateWindows()` 丢进后台，因为它会修改共享状态。预热转移成本，不降低总工作量，也不能帮助启动后立即触发的情况。

5. **保留 grid 的 row stacks，布局未变化时只重新绑定 cell 内容。**  
   **位置：** `src/SwitcherPanel.swift:83`、`src/SwitcherPanel.swift:104`、`src/SwitcherPanel.swift:161`。**预期收益：** warm open 约 **2–6 ms**，release 路径还可省去拆除视图的工作；均待测。**工作量：M；风险：中；证据：estimate。**  
   pooled cells 已存在，但每次关闭都拆 rows，打开时又创建 rows、重新加入全部 cells。按窗口数、columns、cell 尺寸决定是否重建，正常关闭只 `orderOut`。brief 的 warm 总计 35 ms、枚举 24 ms，剩余约 **11 ms 包含全部其他工作**，不能声称这里还能省几十毫秒。测试窗口数量变化、屏幕变化和点击索引重绑定。

6. **复用本次枚举获得的 AX element，减少 release 后再次查找目标。**  
   **位置：** `src/WindowModel.swift:183`、`src/WindowActivator.swift:81`、`src/WindowActivator.swift:86`。**预期收益：** 普通 raise 约 **5–30 ms**；目标失效需重新查询时约 **0 ms**。**工作量：M；风险：中至高；证据：estimate。**  
   枚举已经拿到窗口 AX element，却只保留 ID；释放时再次读取窗口列表。可在本次 activation 内保存 `(PID, windowID) → AX element`，交给现有串行 queue 使用，失败时做一次受控重新解析。不要建立永久 AX cache；窗口关闭、重建以及 element 的有效期必须用 fake 覆盖。

7. **把同步枚举移出 main，主要改善输入响应和长尾，不保证更早显示面板。**  
   **位置：** `src/AppDelegate.swift:108`、`src/WindowModel.swift:145`、`src/HotkeyManager.swift:131`。**预期收益：** 从 main 移走约 **24 ms warm／142 ms cold** 的已测枚举占用；panel wall-clock 改善可能为 **0 ms**。**工作量：M；风险：中；证据：measured 基线 + estimate。**  
   `concurrentPerform` 并不会让调用方异步返回，main 仍等待全部结果。需要显式的 opening 状态，累计期间的 cycle 输入，并处理 release/cancel；MRU 仍串行更新。用延迟 fake 验证“结果返回前已释放”不会稍后弹出面板或激活错误窗口。

## Lighter code

以下为净删行数估算，不含纯格式调整；与上节方案重叠的部分不可重复计算。

1. **删除确认无调用的 initializer、字段和 import。**  
   **位置：** `src/ThumbnailView.swift:39`、`src/WindowModel.swift:88`、`src/AppDelegate.swift:17`。**预期收益：约 7 行，约 0 ms；工作量：S；风险：低；证据：estimate（全源码引用检查）。**  
   `ThumbnailView(windowInfo:width:height:)` 无调用；`selfBundleID` 无读取；`AppDelegate` 不使用 ServiceManagement。

2. **删除无人消费的 stored bounds，并直接更新标题。**  
   **位置：** `src/WindowModel.swift:29`、`src/WindowModel.swift:33`、`src/WindowModel.swift:152`、`src/WindowModel.swift:350`。**预期收益：约 10–15 行，<1 ms；工作量：S；风险：低；证据：estimate。**  
   `bounds` 只被构造和复制；activation 的“approximate bounds”注释没有对应实现。保留 CG 的尺寸过滤，删掉无用途的坐标存储；把 `windowTitle` 改为可更新字段，移除 `withTitle` 的整结构重建。若决定真正实现 bounds 匹配，则应保留该字段。

3. **合并 unminimize／raise 的重复解析和执行代码。**  
   **位置：** `src/WindowActivator.swift:58`、`src/WindowActivator.swift:78`、`src/WindowActivator.swift:90`。**预期收益：约 20–30 行；最小化 raise 收益同上节第 2 项；工作量：S；风险：低至中；证据：estimate。**  
   用一个目标解析函数返回 AX element，再在单一位置执行动作；不要为三处重复动作引入新的 service 层。

4. **单一 panel 到 AppDelegate 的点击通知改为 typed closure。**  
   **位置：** `src/AppDelegate.swift:50`、`src/SwitcherPanel.swift:195`、`src/SwitcherPanel.swift:205`。**预期收益：约 8–12 行，<1 ms；工作量：S；风险：低；证据：estimate。**  
   `onSelect: (Int) -> Void` 可移除 notification name、`userInfo` 字符串键及类型转换。保留 active/index 检查和 `[weak self]`，不影响 click-to-switch。

5. **用 cell 自己的 layer 画选中边框，移除专用 border view。**  
   **位置：** `src/ThumbnailView.swift:29`、`src/ThumbnailView.swift:66`、`src/ThumbnailView.swift:108`、`src/ThumbnailView.swift:160`。**预期收益：约 12–18 行；每个 cell 少一个 view 和四条 constraints，ms 未测；工作量：S；风险：低至中；证据：estimate。**  
   保留同样的边框宽度、圆角及 hover；需要静态渲染检查，确认根 layer 的边框与原布局一致。

6. **统一 recording 状态，并移除低于最低系统版本的分支。**  
   **位置：** `src/PreferencesMenu.swift:163`、`src/PreferencesMenu.swift:215`、`src/HotkeyManager.swift:324`、`src/PreferencesMenu.swift:82`、`src/PermissionManager.swift:59`。**预期收益：约 9–12 行，约 0 ms；工作量：S；风险：低；证据：estimate。**  
   recorder 的 `recording` 与 `ShortcutSettings.isRecording` 始终同步写入，保留一个来源即可。按 brief 的 macOS 13+ 下限，13.0 availability 分支可删；**14.0 捕获分支仍需要保留**。

## Bugs / risks

1. **现有日志不能直接证明“按键到可见”或“释放到实际切换”的端到端耗时。**  
   **位置：** `src/HotkeyManager.swift:229`、`src/AppDelegate.swift:107`、`src/AppDelegate.swift:123`、`src/SwitcherPanel.swift:140`、`src/WindowActivator.swift:45`。**预期收益：0 ms，避免错误归因；工作量：S；风险：低；证据：estimate（源码计时边界）。**  
   open 计时从 delegate 执行开始，漏掉 main 排队；thumbnail 计时沿用同一起点，包含枚举；raise 计时开始于 `app.activate` 之后，结束于 AX 调用返回，没有验证屏幕已完成切换。应分别记录事件、delegate、CG、AX、panel ordered、首张／末张图片及动作结果；不能把 301 ms 全归因于截图 API。

2. **0.25 秒 timeout 没有覆盖 window elements，AX pass 也并非每 app 一次 IPC。**  
   **位置：** `src/WindowModel.swift:96`、`src/WindowModel.swift:179`、`src/WindowModel.swift:185`、`src/WindowModel.swift:194`、`src/WindowModel.swift:205`。**预期收益：** 显式设置 window timeout 后，单次受影响调用的等待预算可由 1,000 ms 降至 250 ms；整轮仍可能累积多次等待。**工作量：S；风险：中；证据：Apple docs；实际长尾为 estimate。**  
   Apple 明确 timeout 只作用于指定 element；app element 的值不会自动传给返回的 windows。全局这里设为 1 秒，因此子窗口查询仍可能等待更久。应设置每个 window 的预算，并限制整轮继续发起的请求；SPI 是否完全遵循该 timeout 属于 **estimate**。[AXUIElementSetMessagingTimeout](https://developer.apple.com/documentation/applicationservices/1459345-axuielementsetmessagingtimeout)

3. **main 上仍有其他同步 AX／icon 工作，后台 raise 没有消除这些阻塞。**  
   **位置：** `src/WindowModel.swift:238`、`src/WindowModel.swift:251`、`src/WindowModel.swift:279`、`src/WindowModel.swift:293`、`src/WindowModel.swift:331`。**预期收益：** 正常路径未量化；受阻的 focus 查询可占用接近 1 秒的消息预算。**工作量：M；风险：中；证据：estimate。**  
   app activation 回调在 main 查询 focused window；observer 安装和 icon 预热也在 main。`main.async` 只是推迟执行，不能避免随后阻塞 event tap。把 AX 查询交给有界 worker，结果合并时验证 PID／事件序号；icon 预热至少分批，不能未经验证就把所有 AppKit 对象访问移到后台。

4. **旧捕获结果会先写 cache，再被 activation guard 拒绝；并发上限实际上是“每轮 8 个”。**  
   **位置：** `src/WindowCapture.swift:49`、`src/WindowCapture.swift:52`、`src/WindowCapture.swift:84`、`src/AppDelegate.swift:124`、`src/AppDelegate.swift:173`。**预期收益：** 消除旧图覆盖新图，并减少快速反复打开时的资源竞争；ms 未测。**工作量：M；风险：中；证据：estimate。**  
   A、B 两轮倒序完成时，A 仍可覆盖 B 已写入的 cache；关闭没有取消捕获，N 轮最多可有约 `8N` 个在途请求。把 generation 检查放到 cache 写入前，限制全局在途工作，取消后停止提交后续任务。不要假设取消 Swift Task 就能立即停止 ScreenCaptureKit 的底层工作——这是 **estimate**。

5. **权限恢复只重建 event tap，没有补装失败的 AXObservers；旧 tap retry 也可能在 stop 后继续执行。**  
   **位置：** `src/AppDelegate.swift:64`、`src/WindowModel.swift:285`、`src/WindowModel.swift:293`、`src/HotkeyManager.swift:77`、`src/HotkeyManager.swift:93`。**预期收益：0 ms，恢复可靠的 shortcut 与同 app MRU；工作量：M；风险：中；证据：estimate。**  
   observer 注册返回值被忽略，失败后仍可能存入 `axObservers`，阻止后续重试。授予权限时应重试缺失／失败的注册。tap retry 需要 running/generation guard，否则 `stop()` 之后排队的 closure 仍可尝试安装。用 fake 权限状态和调度器覆盖 revoke→grant、stop→迟到 retry。

6. **AX 查询短暂失败会永久丢失部分 MRU 历史，新窗口加入顺序也不确定。**  
   **位置：** `src/WindowModel.swift:181`、`src/WindowModel.swift:161`、`src/WindowModel.swift:229`。**预期收益：MRU 稳定性；23 窗口下速度收益 <1 ms；工作量：M；风险：中；证据：estimate。**  
   AX 失败被表示为“空结果”，最小化窗口随后被 prune；恢复时又从 `Set` 遍历顺序追加。应区分扫描失败和确认关闭，按有序窗口列表追加未知 ID。另建 membership set 可把追加阶段从 O(n²) 降到 O(n)，但性能不是主要理由。

7. **raise 可能作用于错误窗口，旧 activation 的排队动作也可能迟到。**  
   **位置：** `src/WindowActivator.swift:46`、`src/WindowActivator.swift:98`、`src/WindowActivator.swift:110`、`src/AppDelegate.swift:166`。**预期收益：避免误切换和积压；正常 ms 收益未量化；工作量：M；风险：中；证据：estimate。**  
   ID 未命中后，重复标题会选第一个匹配窗口，最终甚至直接 raise app 的首窗口；动作错误全部忽略，而 MRU 已提前提升。建议明确区分目标已消失与 SPI 不支持，歧义时不要任意选窗口。串行 queue 加最新请求序号，在发起下一步动作前丢弃过时请求；已发送的 AX 动作无法据此撤销。

8. **cell pool 保留历史峰值及旧图片，cache pruning 并不能释放所有 thumbnail。**  
   **位置：** `src/SwitcherPanel.swift:26`、`src/SwitcherPanel.swift:113`、`src/SwitcherPanel.swift:166`、`src/ThumbnailView.swift:151`、`src/WindowCapture.swift:34`。**预期收益：降低长期内存占用；ms 未测；工作量：S；风险：低；证据：estimate。**  
   pool 只增不减，未使用的 cells 继续持有 `imageView.image`。缩减后清空闲置 cell 的图片和 closure，并保留小量复用余量即可；不要每次关闭销毁整个 pool。cache 本身会在下次打开时过滤，因此不能简单称其“永久无界”。

9. **macOS 13 路径没有 live thumbnails，权限菜单却仍会申请 Screen Recording。**  
   **位置：** `src/WindowCapture.swift:45`、`src/PermissionManager.swift:127`、`src/PreferencesMenu.swift:97`。**预期收益：补齐 macOS 13 功能，速度收益不适用；工作量：M；风险：中；证据：estimate（源码分支）。**  
   若 brief 的 macOS 13+ 包含缩略图支持，当前实现不满足：授权后仍只显示 icons。需要受权限保护的 13 专用捕获后端；不能通过提高最低系统版本来“简化”。如采用旧 CG 捕获 API，应严格限制在兼容分支，其 API 已被 Apple 标记 deprecated。[CGWindowListCreateImage](https://developer.apple.com/documentation/coregraphics/cgwindowlistcreateimage)

10. **grid 的最小 scale 与固定内部尺寸不能保证任意窗口数量下仍正确显示。**  
    **位置：** `src/SwitcherPanel.swift:189`、`src/ThumbnailView.swift:139`、`src/ThumbnailView.swift:140`。**预期收益：保持 fit-screen 和有效布局；速度收益不适用；工作量：M；风险：中；证据：estimate（公式复算，未运行 AppKit）。**  
    以 1280×720 visible area 计算，500 窗口得到约 25×20-point cell，容不下固定 labels；1,000 窗口得到 15-point 宽度，`width−16` 变成负数。需要让 spacing、内部 padding 和文字布局一起适配，不能只 clamp 外层 scale。

## Not worth it

1. **不要撤回并行 AX 扫描，也不要为了大 O 重写小数组。**  
   **位置：** `src/WindowModel.swift:145`、`src/WindowModel.swift:162`、`src/WindowModel.swift:232`。**预期收益：** 改顺序扫描反而预计增加约 **3–5 ms**；23 窗口的集合／排序微优化通常 <1 ms。**工作量：S–M；风险：中；证据：measured harness + estimate。**  
   harness 已给出 parallel warm 3–5 ms 对 sequential 约 8 ms；保留并行结构，优先修失败语义。

2. **不要把重工作直接搬进 event tap callback 来省一次 main dispatch。**  
   **位置：** `src/HotkeyManager.swift:131`、`src/HotkeyManager.swift:229`、`src/AppDelegate.swift:108`。**预期收益：** 无排队时通常 <1 ms；**工作量：S；风险：高；证据：estimate。**  
   回调和 delegate 本来就在同一 main run loop；同步调用会把枚举与建 UI 纳入 callback。真正的问题是 main 被阻塞，删掉异步边界不能解决它。

3. **不要直接把 8 个捕获并发提高到全部窗口，或立即换成每窗口常驻 SCStream。**  
   **位置：** `src/WindowCapture.swift:26`、`src/WindowCapture.swift:77`、`src/WindowCapture.swift:112`。**预期收益：未知，可能退化；工作量：S／L；风险：中／高；证据：estimate。**  
   当前没有 shareable-content、单张截图和任务排队的分段数据。先修跨 activation 的并发失控、渐进显示和输出尺寸；常驻 streams 会增加生命周期代码和后台工作。

4. **不要用永久窗口快照或长期 SCShareableContent cache 替代真实枚举。**  
   **位置：** `src/WindowModel.swift:123`、`src/WindowModel.swift:293`、`src/WindowCapture.swift:62`。**预期收益：** 跳过枚举理论上可省当前 warm 的约 **24 ms**，但保持正确性的净收益未知。**工作量：L；风险：高；证据：measured 基线 + estimate。**  
   目前只监听 focused-window 变化，没有完整覆盖创建、关闭、最小化、标题和空间变化。短期预热值得试；完整事件驱动 cache 的维护成本不符合这次“lighter code”的优先级。

5. **不要删除 permission monitor、AX focus observers、icon cache 或 cell pooling 来追求行数。**  
   **位置：** `src/PermissionManager.swift:92`、`src/WindowModel.swift:285`、`src/WindowModel.swift:52`、`src/SwitcherPanel.swift:26`。**预期收益：** 无已证实正收益；删除 pooling 可能回到已测 **72–98 ms** warm open。**工作量：S；风险：高；证据：measured + estimate。**  
   前两者维护明确要求的权限恢复和 MRU；后两者已经直接服务热路径。应删重复实现和闲置状态，保留这些职责。
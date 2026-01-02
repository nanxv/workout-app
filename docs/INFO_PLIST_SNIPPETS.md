# Info.plist 片段（直接复制到 iOS target 的 Info.plist）

```xml
<key>NSHealthShareUsageDescription</key>
<string>用于读取并展示你的跑步与训练数据（例如 Nike Run Club 同步到"健康"的记录）。</string>
<key>NSHealthUpdateUsageDescription</key>
<string>用于将本应用记录的力量训练写入"健康"。</string>
<key>NSCalendarsUsageDescription</key>
<string>用于把你的训练记录添加到系统日历。</string>
```

> watchOS target 请开启 Capabilities: HealthKit + Background → Workout Processing（无需这些文本键）。


# Full catalog mapping (Three Kingdoms skin)

This file maps every Artifact Classic card that was not in the first release (254 cards) to its Three Kingdoms name. The 49 cards of that release are not repeated. Since milestone M3, 95 of the 254 are in the game (every red and green card, plus the signature improvements of Mazzie, Pugna and Enchantress); their text in `data/locale/cards.json` comes from this mapping, with numbers as `{placeholders}`. Mechanics and numbers are Valve's final post-patch values; only names, text and art change.

The full data (zh/en rules text, Valve's text, ability names, art subject) is in `data/catalog/catalog_mapping.json`. This table is the readable summary.

| Group | Count |
|---|---|
| Hero | 38 |
| Spell | 95 |
| Creep | 37 |
| Improvement | 39 |
| Item | 40 |
| Token | 5 |
| **Total** | **254** |

## Art still needed

- **216 new card images**: 95 spells, 37 creeps, 39 improvements, 40 items and 5 tokens. Each row's `art_subject` is the subject sentence; wrap it in the style bible from `docs/art/ART_PROMPTS.md` (framing rule, faction line, style block and negative line, word for word).
- **3 hero portraits to regenerate**, because the hero changed faction: 孙尚香 (Wu to Shu), 孙坚 (Wu to Qun) and 陈宫 (Qun to Wei).
- The other 35 reserve portraits in `assets/art/heroes_reserve/` already fit their factions.

## Faction moves

Valve's remaining heroes are red 10, blue 10, green 8 and black 10, but the reserve lists were Shu 9, Wei 9, Wu 10 and Qun 10. Three figures move:

- 孙尚香, Wu to Shu (red, Mazzie): Liu Bei's wife, who lived in his household at Gong'an.
- 孙坚, Wu to Qun (black, Sorla Khan): died in 191 as a coalition warlord, before Wu existed.
- 陈宫, Qun to Wei (blue, Outworld Devourer): Cao Cao's first strategist, who won him Yanzhou.

## New glossary terms

| English | 中文 |
|---|---|
| Retaliate | 反击 |
| Cleave | 横扫 |
| Regeneration | 再生 |
| Damage Immunity | 免疫伤害 |
| Death Shield | 免死 |
| Stun | 眩晕 |
| Disarm | 缴械 |
| Taunt | 嘲讽 |
| Lock | 锁定 |
| Bounty | 悬赏 |
| Soulbound | 同命 |
| Quicken | 加速 |
| Purge | 驱散 |
| Pierce (keyword) | 穿透 |
| Charge | 充能（层） |
| Rapid Deployment | 快速出阵 |
| Play effect | 出场效果 |
| Death effect | 阵亡效果 |
| Equip effect | 装备效果 |
| Base copy | 基础副本 |
| Deployment / action / combat phase | 部署阶段 / 行动阶段 / 交战阶段 |
| Modify (permanent stat change) | 永久使 … / permanently give |
| Modify (add text to a card) | 附加 / modify … with |

Active abilities always read `名称：效果。主动技能，冷却N。` / `Name: effect. Active ability; cooldown N.`, the same as the mapped heroes.

## Tokens

| 中文名 | English | original Valve card | summoned by |
|---|---|---|---|
| 木兽 | Wooden Beast | Loyal Beast | Huang Yueying's 巧造木兽 (Call of the Wild) |
| 屯田兵 | Farm Soldier | Plague Ward | Deng Ai's 屯田 passive and 屯兵淮南 (Sow Venom) |
| 拒马 | Spiked Barricade | Roseleaf Wall | 濡须筑坞 (Defensive Bloom) |
| 阴兵 | Ghost Soldier | Zombie | Lu River Veterans (Cursed Satyr) and Soul-Calling Banner (Book of the Dead) |
| 饿虎 | Hungry Tiger | Hound of War | Xun Yu's 驱虎吞狼 (Prey on the Weak): fast, fierce and fragile predators set on the wounded. |

## 蜀 Shu (red)

### 武将 Heroes (10)

| 中文名 | English | original Valve card | type | cost | ability | signature | rationale |
|---|---|---|---|---|---|---|---|
| 姜维 | Jiang Wei | Centaur Warrunner | Hero 4/0/14 | - | 胆大如斗（被动） | 九伐中原 Nine Northern Campaigns | When Jiang Wei died his gall was found to be 'as big as a 斗' (世语), so he punishes anyone who strikes him. His nine all-out northern campaigns, all offence and no defence, are Double Edge (+8 attack / -8 armor). |
| 赵云 | Zhao Yun | Timbersaw | Hero 4/0/11 | - | 龙胆（被动） | 七进七出 Seven Charges Through | The more enemies surround Zhao Yun, the harder he is to kill, as at Changban where he cut through Cao's ranks again and again (三国杀 龙胆). Avoids the mapped 一身是胆 and 长坂怒喝. |
| 庞统 | Pang Tong | Tidehunter | Hero 2/1/18 | - | 铁索连舟（主动4） | 耒阳断案 Leiyang Verdicts | In 演义 ch.47 Pang Tong persuades Cao Cao to chain his fleet together, leaving it unable to move: a field-wide stun. This is a different event from the mapped 连环计 (Wang Yun's Diaochan scheme). He cleared a hundred days of Leiyang cases in half a day (ch.57), the cheap 'get initiative' signature. |
| 黄月英 | Huang Yueying | Beastmaster | Hero 5/0/12 | - | 巧造木兽（主动3） | 火兽破阵 Fire Beasts Break Ranks | In 演义 ch.90 Shu routs King Mulu's beast army with fire-breathing wooden beasts, a device folk tradition credits to the inventor Huang Yueying. Summoning a war beast and scattering the enemy line is Beastmaster's kit. |
| 黄忠 | Huang Zhong | Bristleback | Hero 8/0/12 | - | 定军山（被动） | 烈弓 Fierce Bow | At Dingjun Mountain Huang Zhong cut down the enemy general Xiahou Yuan, so he hardens after killing a hero. 烈弓 (his 三国杀 skill) is the armor-shredding signature arrow. Avoids the mapped 老当益壮. |
| 诸葛亮 | Zhuge Liang | Pugna | Hero 6/0/9 | - | 看破（主动3） | 将计就计 Turn the Tables | Zhuge Liang is the counter-strategist: 看破 (his 三国杀 skill) sees through and dismantles an enemy work, and his signature 将计就计 turns every enemy scheme back on the schemer. Avoids the reserved 八阵图 / 空城计 / 草船借箭, the mapped 东风, and 火烧博望 (now the red Raze card). |
| 孙尚香 | Sun Shangxiang | Mazzie | Hero 6/3/6 | - | 无 | 孙夫人城 Lady Sun's Fort | Faction move Wu to Shu. As Liu Bei's wife she lived in his household at Gong'an, and the SP 孙尚香 in 三国杀 is Shu. The armed, armoured lady (her maids carried blades) suits a 6/3/6 heavy-armour vanilla hero. 孙夫人城 at Gong'an is the tower-armor signature. |
| 刘备 | Liu Bei | Sven | Hero 5/0/11 | - | 双股剑（被动） | 髀肉之叹 Lament of Idle Thighs | Liu Bei's paired swords (双股剑) sweep both sides. 髀肉之叹, his lament that idleness had fattened his thighs, is the return to war that permanently powers up a red hero. Avoids the reserved 桃园结义 (red's 8-mana spell) and 三顾茅庐. |
| 马超 | Ma Chao | Legion Commander | Hero 6/1/8 | - | 神威（被动） | 夜战葭萌关 Night Duel at Jiameng | Ma Chao, hailed in 演义 as the 'Divine Might General' (神威天将军), punishes every attacker. His torch-lit night duel with Zhang Fei at Jiameng Pass is the most famous one-on-one fight in the novel, so it is his Duel signature. |
| 魏延 | Wei Yan | Ursa | Hero 7/0/10 | - | 狂骨（被动） | 镇守汉中 Hold Hanzhong | Wei Yan is a ferocious, relentless brawler (三国杀 狂骨), and each blow strips more armour. His boast on taking command of Hanzhong, that he would hold it against Cao Cao's whole realm, is the +4/+4 signature. |

### 计策 Spells (26)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 耒阳断案 | Leiyang Verdicts | Kraken Shell | Spell, signature of 庞统 | 1 | Pang Tong's signature. Sent to Leiyang as a minor magistrate, he cleared a hundred days of cases in half a day (演义 ch.57): a cheap card that seizes the initiative and leaves a small lasting gain. |
| 九伐中原 | Nine Northern Campaigns | Double Edge | Spell, signature of 姜维 | 1 | Jiang Wei's signature. He marched north against Wei again and again, pouring everything into attack and leaving Shu's defences thin: +8 attack for -8 armor is that all-or-nothing gamble. |
| 拖刀计 | Trailing-Blade Feint | Poised to Strike | Spell | 1 | The novel's famous trick of feigning retreat with the blade trailing, then wheeling for a sudden killing cut: a cheap one-round burst of attack. |
| 张松献图 | Zhang Song's Map | New Orders | Spell | 1 | Zhang Song secretly gave Liu Bei a map of Yi Province's roads and garrisons, showing exactly where to strike: a cheap card that chooses an ally's target. |
| 傅彤断后 | Fu Tong's Rearguard | Fight Through the Pain | Spell | 1 | At Yiling Fu Tong held the rear so Liu Bei could escape and refused to surrender to the end: a one-round armor surge that buys the tempo. |
| 七进七出 | Seven Charges Through | Whirling Death | Spell, signature of 赵云 | 2 | Zhao Yun's signature. At Changban he rode in and out of Cao Cao's army again and again (七进七出 in the novel), wounding and blunting everyone around him. 单骑救主 stays reserved. |
| 廖化先锋 | Liao Hua Leads | Heroic Resolve | Spell | 2 | Liao Hua served Shu from its founding to its fall ('蜀中无大将，廖化作先锋'): a veteran who outlasted everyone, so he grows tougher with every small card. |
| 夜战葭萌关 | Night Duel at Jiameng | Duel | Spell, signature of 马超 | 2 | Ma Chao's signature. At Jiameng Pass he fought Zhang Fei all day and on into the night by torchlight (演义 ch.65), the novel's most famous one-on-one duel. |
| 骂死王朗 | Scolding Wang Lang | Pick a Fight | Spell | 2 | Before the armies in 演义 ch.93, Zhuge Liang taunts the Wei minister Wang Lang so savagely that he falls dead from his horse: the purest taunt in the novel, and it picks the hero's target. |
| 虎父无犬子 | Tiger's Cubs | Rising Anger | Spell | 2 | Guan Xing and Zhang Bao, sons of the fallen sworn brothers, grew fiercer battle by battle as they avenged their fathers: attack that keeps building. |
| 智取瓦口 | Taking Wakou Pass | Smash Their Defenses! | Spell | 3 | Zhang Fei took Zhang He's fortified position at Wakou Pass with a feint and a hidden mountain path (演义 ch.70): one fortification falls, and the scouting draws a card. |
| 法正举旗 | Fa Zheng's Signal | Spot Weakness | Spell | 3 | At Mount Dingjun the advisor Fa Zheng watched for the moment the enemy tired and gave the signal to attack. Seeing the gap lets a whole group ignore armor, and the insight draws a card. |
| 盘蛇谷 | Coiled Serpent Valley | Rend Armor | Spell | 3 | In Coiled Serpent Valley (演义 ch.90) Zhuge Liang turned the oil-soaked rattan armour of Wutugu's army into their doom: armor reduced to nothing. |
| 镇守汉中 | Hold Hanzhong | Enrage | Spell, signature of 魏延 | 4 | Wei Yan's signature. Given command of Hanzhong, he vowed to hold it against Cao Cao's whole realm: a short, all-out surge of strength and defence (+4/+4 this round). |
| 五虎上将 | Five Tiger Generals | Clear the Deck | Spell | 4 | Shu's Five Tiger Generals each swept through enemy ranks. A team-wide burst of cleave honours all five at once without spending any one of them. |
| 回马枪 | Turnback Spear | Sucker Punch | Spell | 4 | The famous 'turnback spear': feign flight, then twist in the saddle and stab the pursuer, who is caught stunned. A classic Shu cavalry trick. |
| 兴复汉室 | Restore the Han | Tresdin's Standards | Spell | 4 | Shu's rallying cause from the Chu Shi Biao: every red card answers the call to restore the Han, lifting the hero and the troops beside him. |
| 烈弓 | Fierce Bow | Viscous Nasal Goo | Spell, signature of 黄忠 | 4 | Huang Zhong's signature. 烈弓 is his 三国杀 skill: arrows from the old general's great bow punch through armour for good (-2 armor, permanent). |
| 攻心为上 | Win Their Hearts | Crippling Blow | Spell | 4 | Ma Su's advice for the Southern Campaign, recorded in 襄阳记: 'attacking the heart is superior to attacking cities'. Breaking a hero's will permanently blunts his attack. |
| 火烧博望 | Fire at Bowang | Raze | Spell | 5 | Zhuge Liang's first battle in 演义 ch.39: he lured Xiahou Dun into Bowang Slope and set the reeds and camp ablaze. Burning every enemy fortification at once is the high-cost wipe of improvements. |
| 温酒斩华雄 | Ere the Wine Cools | Enough Magic! | Spell | 5 | In 演义 ch.5 Guan Yu rides out and returns with Hua Xiong's head before his cup of warm wine has cooled: no more talk, straight to the fight. |
| 鸡肋 | Chicken Rib | Routed | Spell | 6 | Hanzhong, 219: stalled by Liu Bei, Cao Cao gave the night password 'chicken rib' (鸡肋), worthless to keep yet a pity to throw away, and his officers began packing to retreat. Heroes resting in camp lose heart and drain their own side. |
| 髀肉之叹 | Lament of Idle Thighs | God's Strength | Spell, signature of 刘备 | 6 | Liu Bei's signature. Idle at Liu Biao's court, he wept that his thighs had grown fat from years out of the saddle; his return to war permanently powers up a red hero. |
| 火兽破阵 | Fire Beasts Break Ranks | Primal Roar | Spell, signature of 黄月英 | 7 | Huang Yueying's signature. In 演义 ch.90 fire-breathing wooden beasts rout King Mulu's beast army: the front rank is stunned and the troops beside it scatter. |
| 飞军天降 | Flying Army Descends | Spring the Trap | Spell | 7 | Wang Ping's Wudang Flying Army (the mapped Centaur Hunter), light mountain troops from the south, appear wherever they are needed: two of them into any lane. |
| 桃园结义 | Peach Garden Oath | Time of Triumph | Spell | 8 | The reserved set piece goes on red's most expensive spell (8 mana): the oath of brotherhood that founded Shu makes every allied hero stronger in every way, permanently. |

### 兵卒 Creeps (11)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 东州兵 | Dongzhou Exiles | Mercenary Exiles | Creep 2/1/4 | 3 | The Dongzhou troops were refugees from the Central Plains whom the lords of Yi Province paid to fight. Pour in gold and they grow. |
| 绊马索兵 | Snare-Rope Troops | Hellbear Crippler | Creep 3/0/3 | 3 | Snare ropes stretched across a path threw riders and hobbled horses. Anything they hurt fights weaker for good. |
| 蒲元刀匠 | Pu Yuan's Smiths | Smeevil Armsmaster | Creep 2/0/2 | 4 | Pu Yuan, Shu's master swordsmith, forged 3,000 blades for Zhuge Liang's army (蒲元传). His smiths arm a hero when they arrive. |
| 涿郡义兵 | Zhuo Volunteers | Rebel Instigator | Creep 2/0/3 | 4 | Liu Bei's first army was village volunteers from Zhuo who swelled with every victory over the rebels: when they win a fight, more join. |
| 牙门旗手 | Yamen Standard Bearer | Legion Standard Bearer | Creep 0/0/6 | 4 | Shu's 牙门 command banner (the rank Wang Ping and Wei Yan held) marked where the army rallied. The 0/0/6 bearer cannot fight but drives the soldiers beside him. |
| 虎步军 | Tiger-Step Elite | Stonehall Elite | Creep 4/2/2 | 4 | Zhuge Liang's 虎步 guard were Shu's elite heavy infantry, and they grew bolder with every foe they cut down. |
| 连弩手 | Repeating Crossbowmen | Ogre Corpse Tosser | Creep 2/0/10 | 5 | Shu's repeating crossbows shot over the front line at the walls. Each fallen Foot Soldier (the melee_creep token) clears their line of fire. |
| 泸水残兵 | Lu River Veterans | Cursed Satyr | Creep 6/0/6 | 5 | Zhuge Liang's southern army crossed the Lu River, where the restless dead rose until he appeased them with offerings (演义 ch.91). These hardened veterans fight well (6/0/6), but the ghosts they leave behind rise for the enemy (the Zombie token, 阴兵). |
| 西凉铁骑 | Xiliang Iron Cavalry | Red Mist Pillager | Creep 4/0/2 | 5 | Ma Chao's northwestern horsemen followed him into Shu. Raiders who break through to the walls bring more riders. |
| 木牛流马 | Wooden Ox | Keenfolk Golem | Creep 13/0/13 | 6 | Zhuge Liang's wooden ox is the era's legendary machine. A 13/0/13 construct whose cost, building it, uses up every resource you hold. |
| 板楯蛮 | Banshun Shieldmen | Marrowfell Brawler | Creep 6/0/16 | 6 | The Ba region's 'board-shield' tribesmen were famed since the Han as nearly unbreakable fighters, which fits a huge-health vanilla 6/0/16. |

### 营建 Improvements (7)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 滚木礌石 | Logs and Boulders | Burning Oil | Improvement | 1 | The classic wall defence of the era: logs and boulders rolled down on attackers, which is tower retaliate. |
| 蜀道 | Road to Shu | Path of the Bold | Improvement | 3 | The perilous plank roads into Shu (Li Bai's 蜀道难) could only be walked by the bold. Every red card toughens someone who walks them. |
| 成都武库 | Chengdu Arsenal | Temple of War | Improvement | 3 | Shu's capital arsenal kept the armies equipped. It boosts every equipped hero, the opponent's included, exactly as Valve's 'all equipped heroes'. |
| 阵前斗将 | Clash of Champions | Grand Melee | Improvement | 3 | In 演义 battles often open with champions duelling between the lines while both armies watch. A red hero turns the lane into that arena, and every hero cleaves. |
| 将计就计 | Turn the Tables | Nether Ward | Improvement, signature of 诸葛亮 | 4 | Zhuge Liang's signature. In 演义 he repeatedly turns his rivals' schemes back on them (Zhou Yu's above all): every enemy stratagem backfires on its own tower. |
| 孙夫人城 | Lady Sun's Fort | Steel Reinforcement | Improvement, signature of 孙尚香 | 4 | Sun Shangxiang's signature. 水经注 records a 孙夫人城 near Gong'an, the fort where Liu Bei's armed Wu bride kept her household: a hardened tower. |
| 白帝城 | Baidi Citadel | The Omexe Arena | Improvement | 6 | At Baidi City the dying Liu Bei entrusted his son and his realm to Zhuge Liang. Each death passes something on (a card). |

## 魏 Wei (blue)

### 武将 Heroes (10)

| 中文名 | English | original Valve card | type | cost | ability | signature | rationale |
|---|---|---|---|---|---|---|---|
| 邓艾 | Deng Ai | Venomancer | Hero 2/0/6 | - | 屯田（被动） | 屯兵淮南 Garrison the Huai | Deng Ai founded the Huai river military-farm colonies (三国杀 skill 屯田). Steady free troops every round fit Venomancer's ward-per-deployment passive. Signature 屯兵淮南 summons two more Farm Soldiers. |
| 夏侯渊 | Xiahou Yuan | Meepo | Hero 4/0/5 | - | 神速（主动2）；同气连枝（被动） | 分兵疾进 Split and Advance | Wei said of Xiahou Yuan's speed '三日五百，六日一千', and 三国杀 gives him 神速. A hero who jumps to wherever his copies are suits a general who seemed to be on every front at once. Signature 分兵疾进 summons another Xiahou Yuan. |
| 甄姬 | Zhen Ji | Luna | Hero 3/0/8 | - | 倾国（被动） | 洛神赋 Ode to the Luo Goddess | Luna is a moon caster. Zhen Ji is tied by legend to Cao Zhi's Ode to the Luo River Goddess (三国杀 skills 倾国 / 洛神), so the beam that charges the 'Ode' carries her legend. |
| 荀彧 | Xun Yu | Kanna | Hero 2/0/12 | - | 王佐之才（被动） | 驱虎吞狼 Tiger Against Wolf | He Yong judged the young Xun Yu 'a talent to aid a king' (王佐才也), and he gathered men and supplies for Cao Cao's cause, which fits troops flocking to his lane. 驱虎吞狼 is his stratagem in 演义 ch.14, and summoning predators onto wounded units is that plan in action. |
| 张辽 | Zhang Liao | Earthshaker | Hero 2/0/7 | - | 突袭（主动4） | 辽来止啼 Liao Is Coming | Zhang Liao's shock raids stun the line (三国杀 突袭). His name alone hushed crying children in Wu (辽来止啼), so the more enemies there are, the further the terror spreads. Avoids the mapped 威震逍遥津. |
| 郭嘉 | Guo Jia | Ogre Magi | Hero 3/0/7 | - | 天妒（被动） | 十胜十败 Ten Wins, Ten Losses | Guo Jia's 三国杀 skill 天妒 keeps the card that was drawn against him, which maps onto free copies of spells. His 'ten victories, ten defeats' analysis of Yuan Shao is a lasting edge that grinds the enemy down every round. Only the event name 遗计 is used by a mapped card. |
| 陈宫 | Chen Gong | Outworld Devourer | Hero 4/0/7 | - | 明策（被动） | 捉放曹 Catch and Release | Faction move Qun to Wei. Chen Gong was Cao Cao's first strategist and won him Yanzhou in 192; in 演义 he frees the captured Cao Cao, so 捉放曹 (seize, then spare) is Astral Imprisonment. 明策 is his 三国杀 skill. |
| 许褚 | Xu Chu | Prellex | Hero 3/0/5 | - | 乡勇（被动） | 虎卫营 Tiger Guard Camp | Xu Chu raised a clan militia of thousands to hold his walled village against the Yellow Turbans, then led Cao Cao's Tiger Guard (虎卫). A steady stream of Foot Soldiers and a barracks signature fit both. |
| 典韦 | Dian Wei | Skywrath Mage | Hero 3/0/6 | - | 强袭（主动2） | 掷短戟 Hail of Short Halberds | At Puyang Dian Wei hurled armfuls of short halberds into the closing enemy, splitting damage across a group (the signature). 强袭 is his 三国杀 skill. His death at Wancheng (the mapped 宛城之变) is avoided. |
| 夏侯惇 | Xiahou Dun | Crystal Maiden | Hero 2/0/5 | - | 清俭（被动） | 拔矢啖睛 Eating His Own Eye | 三国志 calls Xiahou Dun 性清俭: he gave away his surplus wealth and built dams as a governor, which suits a mana-refund support (三国杀 清俭). When an arrow took his eye he pulled it out and ate it, a sight that leaves the enemy too shaken to strike (the disarm signature). |

### 计策 Spells (28)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 虎豹骑冲阵 | Tiger-Leopard Charge | Strafing Run | Spell | 1 | Cao Cao's elite Tiger and Leopard Cavalry rode down infantry formations: a cheap sweep that hits every enemy creep but no heroes. |
| 割发代首 | Hair for a Head | Diabolic Revelation | Spell | 1 | When his horse trampled the crops he had forbidden anyone to touch, Cao Cao cut off his hair in place of his head: self-punishment that tightened discipline. Cards paid for by hurting your own side. |
| 激将法 | Provocation | Ventriloquy | Spell | 1 | Goading a general into rash action (激将法) recurs throughout the novel: force a unit to taunt and draw the enemy's blows where you want them. |
| 割须弃袍 | Cut Beard, Shed Robe | Cunning Plan | Spell | 2 | Chased by Ma Chao at Tong Pass, Cao Cao cut his beard and threw off his red robe so the pursuers lost him among his own men (演义 ch.58): swap places with an ally and slip away. |
| 梦中杀人 | Killing in My Dreams | Whispers of Madness | Spell | 2 | Cao Cao claimed he killed people in his sleep and executed an attendant who covered him (演义 ch.72); afterwards no one dared approach. Stunning a foe also freezes your own heroes. |
| 煮酒论英雄 | Heroes Over Plum Wine | Rolling Storm | Spell | 3 | As Cao Cao and Liu Bei discussed heroes over green-plum wine, a thunderclap shook them both (演义 ch.21). A storm that hits every tower on both sides fits that shared jolt. |
| 拔矢啖睛 | Eating His Own Eye | Frostbite | Spell, signature of 夏侯惇 | 3 | Xiahou Dun's signature. Struck in the eye by an arrow, he pulled it out and ate the eye (演义 ch.18); the enemy archer was too stunned to fight back. |
| 千金悬赏 | Thousand-Gold Bounty | Wrath of Gold | Spell | 3 | Warlords of the era posted huge bounties for heads, and hired blades struck at anyone in reach. Pouring all your gold into random bloodshed on both sides is that reckless price. |
| 徐晃援樊 | Xu Huang's Relief | Better Late Than Never | Spell | 3 | Xu Huang waited for enough men before marching to relieve Fancheng, arrived late, and still broke the siege: a single reinforcement for whichever lane needs it. |
| 缓兵之计 | Stalling Tactics | Buying Time | Spell | 3 | The classic delaying stratagem used throughout the novel: a lighter lock that holds the enemy back a few rounds. |
| 调虎离山 | Lure the Tiger | Compel | Spell | 3 | One of the Thirty-Six Stratagems: draw the tiger off its mountain to face the opponent you choose. A cheaper, card-drawing cousin of the mapped 挟天子以令诸侯. |
| 宁我负人 | Let Me Wrong the World | At Any Cost | Spell | 3 | Cao Cao's notorious line after killing Lü Boshe's household (演义 ch.4), 'I would rather wrong the world than let the world wrong me': ruthless harm to friend and foe alike. |
| 屯兵淮南 | Garrison the Huai | Sow Venom | Spell, signature of 邓艾 | 4 | Deng Ai's signature. He planned and ran the military-farm colonies along the Huai, where soldiers farmed and fought: two more Farm Soldiers (the Plague Ward token). |
| 分兵疾进 | Split and Advance | Divided We Stand | Spell, signature of 夏侯渊 | 4 | Xiahou Yuan's signature. Moving so fast he seemed to be on several fronts at once, he splits off another copy of himself (Valve: summon a Meepo). Engine text must use the hero's display name. |
| 仿造木牛 | Copy the Wooden Ox | ...And One For Me | Spell | 4 | In 演义 ch.102 Sima Yi captures Shu's wooden oxen and has his craftsmen copy them: take an enemy's equipment and make your own. |
| 捉放曹 | Catch and Release | Astral Imprisonment | Spell, signature of 陈宫 | 4 | Chen Gong's signature. In 演义 ch.4 the magistrate Chen Gong seizes the fugitive Cao Cao, then frees him: held out of the fight, but unharmed. |
| 抹书间韩 | The Smudged Letter | Self Sabotage | Spell | 4 | At Tong Pass Cao Cao sent Han Sui a letter full of deliberate smudges, so Ma Chao suspected treachery (演义 ch.59). Poisoning the opponent's cards so they damage their own towers is that planted suspicion. |
| 驱虎吞狼 | Tiger Against Wolf | Prey on the Weak | Spell, signature of 荀彧 | 4 | Xun Yu's signature. His 驱虎吞狼 plan (演义 ch.14) sets a tiger on a wolf; here hungry tigers fall on every wounded unit (the Hound of War token, 饿虎). |
| 声东击西 | Feint East, Strike West | Arcane Assault | Spell | 4 | At Baima Xun You had Cao Cao feint toward Yanjin and then strike the real target: a hit, intelligence gained and the tempo taken. |
| 虚张声势 | Decoy Army | Fog of War | Spell | 4 | Generals raised fake banners and dust clouds (疑兵) so the enemy hesitated: some freeze and some don't, a coin-flip disarm. |
| 洛神赋 | Ode to the Luo Goddess | Eclipse | Spell, signature of 甄姬 | 6 | Zhen Ji's signature. Legend ties her to Cao Zhi's 洛神赋; her passive charges the Ode, and the stored verses fall on the enemy as moonlight. |
| 掷短戟 | Hail of Short Halberds | Mystic Flare | Spell, signature of 典韦 | 6 | Dian Wei's signature. At Puyang he held a dozen short halberds and hurled them into the enemy as they closed (三国志 典韦传): damage split across a group. |
| 千里请战 | Thousand-Li Petition | Lost in Time | Spell | 6 | Sima Yi stalled Zhuge Liang by asking the distant emperor for leave to fight, knowing it would be refused; the enemy's plans sat waiting. Heavy lock on several cards is that delay. |
| 三日五百里 | Three-Day Forced March | Call the Reserves | Spell | 6 | Wei's saying about Xiahou Yuan's troops, 'three days, five hundred li; six days, a thousand': reinforcements that appear in any lane. |
| 二虎竞食 | Two Tigers, One Prey | Friendly Fire | Spell | 6 | Xun Yu's 二虎竞食之计 (演义 ch.14): give one prize to two rivals, Liu Bei and Lü Bu, so they fight each other. |
| 十面埋伏 | Ambush on Ten Sides | Remote Detonation | Spell | 6 | Cheng Yu's ten-sided ambush against Yuan Shao at Cangting (演义 ch.31): the empty ground before the enemy was full of hidden troops. |
| 辽来止啼 | Liao Is Coming | Echo Slam | Spell, signature of 张辽 | 7 | Zhang Liao's signature. After Xiaoyao Ford, Wu mothers hushed crying children with 'Zhang Liao is coming': the more enemies there are, the further the terror spreads. |
| 火烧乌巢 | Burning of Wuchao | Bolt of Damocles | Spell | 10 | Cao Cao's night raid that burned Yuan Shao's grain depot at Wuchao decided Guandu at a stroke. Blue's most expensive spell is that single crushing blow to the enemy tower. |

### 兵卒 Creeps (4)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 敢死士 | Dare-to-Die Men | Relentless Zombie | Creep 2/0/2 | 2 | Han armies raised dare-to-die volunteers (敢死之士) who fought on after wounds that should have killed them: a cheap creep that cheats death once. |
| 典农校尉 | Agrarian Colonel | Satyr Magician | Creep 2/0/5 | 5 | Wei's 典农校尉 officers ran the military farms that fed Cao Cao's armies; this officer refills the tower's Command every round. |
| 管辂 | Guan Lu the Diviner | Troll Soothsayer | Creep 2/0/8 | 6 | Guan Lu was Wei's most famous diviner (三国志 方技传; he reads fates for Cao Cao in 演义 ch.69). A soothsayer who sees ahead is an extra card each round. |
| 曹植 | Cao Zhi | Incarnation of Selemene | Creep 3/0/11 | 9 | Cao Zhi, author of the 洛神赋, was said to hold eight of the world's ten measures of talent (才高八斗) and composed a poem in seven paces. An inspiration that never runs dry refills Command after every card. Pairs with Zhen Ji's signature. |

### 营建 Improvements (10)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 驿站 | Post Station | Messenger Rookery | Improvement | 1 | Han and Wei orders travelled by relay riders between post stations (驿): a cheap work that redirects one ally's attack each round. |
| 斥候营 | Scout Camp | Watchtower | Improvement | 1 | Wei armies kept scout outposts to report every enemy work being built: each enemy improvement in the lane becomes intelligence. |
| 坚壁清野 | Walls and Bare Fields | Fractured Timeline | Improvement | 2 | 'Strengthen the walls, strip the fields' was the standard way to starve an invader's momentum: a lasting work that slows one enemy card every round. |
| 太学 | Imperial Academy | Path of the Wise | Improvement | 3 | Wei re-founded the Imperial Academy in 224 to train its officials. Every blue stratagem gains a scholar's sharp edge. |
| 十胜十败 | Ten Wins, Ten Losses | Ignite | Improvement, signature of 郭嘉 | 3 | Guo Jia's signature. His 'ten victories, ten defeats' comparison of Cao Cao and Yuan Shao (三国志 郭嘉传 注) is a lasting edge that grinds every enemy down, armour or not. |
| 月旦评 | Monthly Appraisals | Howling Mind | Improvement | 3 | Xu Shao's monthly appraisals of notable men famously judged Cao Cao 'a capable minister in peace, a treacherous hero in chaos'. Open commentary informs both sides. |
| 铜雀台 | Bronze Sparrow Terrace | Aghanim's Sanctum | Improvement | 4 | Cao Cao's Bronze Sparrow Terrace at Ye was the seat of Wei power and patronage: a monument that refills your Command every round. |
| 虎卫营 | Tiger Guard Camp | Barracks | Improvement, signature of 许褚 | 5 | Xu Chu's signature. He brought his clan militia to Cao Cao and led the Tiger Guard (虎卫): a camp that keeps sending out men. |
| 强弩营 | Crossbow Battery | Conflagration | Improvement | 5 | Wei's disciplined massed crossbow companies loosed volley after volley into the whole enemy line: 2 damage to every enemy each round. |
| 陷马坑 | Horse Pitfalls | Glyph of Confusion | Improvement | 6 | Concealed pitfalls were dug to trap charging horsemen in many novel battles: anything entering the lane is caught and stunned, friend or foe. |

## 吴 Wu (green)

### 武将 Heroes (8)

| 中文名 | English | original Valve card | type | cost | ability | signature | rationale |
|---|---|---|---|---|---|---|---|
| 周泰 | Zhou Tai | Abaddon | Hero 4/0/9 | - | 不屈（主动2） | 奋身护主 Shield the Lord | Zhou Tai shielded Sun Quan at Xuancheng and survived a dozen wounds (三国杀 不屈). A full self-heal with immunity, plus a shield spell for an ally, is his story. |
| 鲁肃 | Lu Su | Chen | Hero 4/0/9 | - | 缔盟（主动4） | 指囷相赠 Granary Gift | Lu Su is Wu's diplomat (三国杀 缔盟): he wins enemy troops over by persuasion, not force. He gave Zhou Yu a whole granary (指囷相赠), which fits the army-wide full heal of his signature. |
| 黄盖 | Huang Gai | Viper | Hero 4/0/10 | - | 铁鞭（被动） | 诈降火船 Fire Ship Feint | The veteran's iron whip (his weapon in 演义) wears down every attacker. His fake-surrender fire ships kept Cao's fleet burning, so the damage-over-time signature is his. Avoids the reserved 苦肉计 and 火烧赤壁. |
| 大乔 | Da Qiao | Enchantress | Hero 4/0/8 | - | 国色（被动） | 二乔宅 Qiao Sisters' Manor | Da Qiao is a gentle support beauty (三国杀 国色) whose presence restores the allies beside her. The sisters' family home becomes the protective sanctuary signature. |
| 小乔 | Xiao Qiao | Omniknight | Hero 5/0/12 | - | 天香（主动2） | 琴瑟和鸣 Zither in Harmony | Xiao Qiao is the healer counterpart of her sister (三国杀 天香). Her harmony with Zhou Yu, the commander who loved music, becomes the army-wide regeneration blessing. |
| 陆逊 | Lu Xun | Treant Protector | Hero 4/0/10 | - | 坚守（被动） | 陆家部曲 Lu Clan Retainers | At Yiling Lu Xun held his defensive line for months before striking, so he protects his neighbors. The Lu were one of Wu's four great clans, and their retainers feed the war chest (the mana creep signature). |
| 孙策 | Sun Ce | Magnus | Hero 4/1/9 | - | 无 | 激昂 Rousing Fervor | The 'Little Conqueror' is a plain, sturdy 4/1/9 frontliner whose power lies in inspiring others. 激昂 (his 三国杀 skill) is the permanent attack-and-cleave signature he passes to a unit. |
| 太史慈 | Taishi Ci | Dark Seer | Hero 5/0/9 | - | 突围请援（主动2） | 神亭酣斗 Duel at Shenting | Taishi Ci rode out through the siege of Beihai to bring Liu Bei's relief army, which fits moving an ally into another lane. His evenly matched duel with Sun Ce at Shenting is the strike-back signature. |

### 计策 Spells (22)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 金蝉脱壳 | Cicada Sheds Its Shell | Juke | Spell | 1 | One of the Thirty-Six Stratagems: leave an empty shell behind and slip into a new position. |
| 奋身护主 | Shield the Lord | Aphotic Shield | Spell, signature of 周泰 | 2 | Zhou Tai's signature. At Xuancheng he covered Sun Quan with his own body and took a dozen wounds: he shields the unit, strips the enemy's effects and strikes back. |
| 列盾相护 | Shields Together | Defend the Weak | Spell | 2 | Wu's defensive doctrine: one soldier anchors the shield line and protects the men beside him. |
| 擂鼓 | Pounding Drums | Bellow | Spell | 2 | Thundering war drums threw enemy squads into confusion: a cheap spell scatters one troop into another lane. |
| 蒙冲掩护 | Mengchong Cover | Iron Branch Protection | Spell | 2 | Hide-covered mengchong warships darted anywhere on the river to screen troops: a cheap armor buff that reaches any lane. |
| 犒赏三军 | Reward the Army | Rumusque Blessing | Spell | 3 | Wu lords feasted the troops after each victory: every soldier in one chosen lane is fed and made sturdier for good. |
| 诈降火船 | Fire Ship Feint | Viper Strike | Spell, signature of 黄盖 | 3 | Huang Gai's signature. His fire ships sailed in under a false surrender and set Cao's chained fleet burning round after round. Avoids the reserved 苦肉计 and 火烧赤壁. |
| 激昂 | Rousing Fervor | Empower | Spell, signature of 孙策 | 4 | Sun Ce's signature. 激昂 is his 三国杀 skill: the Little Conqueror's fire passes into whoever he leads, a big permanent attack and cleave. |
| 神亭酣斗 | Duel at Shenting | Ion Shell | Spell, signature of 太史慈 | 4 | Taishi Ci's signature. At Shenting Ridge he fought Sun Ce to a standstill, each snatching the other's weapon and helmet: a unit that strikes back at every attacker. |
| 濡须筑坞 | Fortify Ruxu | Defensive Bloom | Spell | 4 | On Lü Meng's advice Wu built the Ruxu dock-fort, which held off Cao Cao's invasions: barricades raised out of nothing (the Roseleaf Wall token, 拒马). |
| 琴瑟和鸣 | Zither in Harmony | Allseeing One's Favor | Spell, signature of 小乔 | 4 | Xiao Qiao's signature. Her marriage to Zhou Yu, the commander famed for his ear for music, is the harmony that heals the whole army. |
| 筑石头城 | Raise Stone City | Restoration Effort | Spell | 4 | Sun Quan built the Stone City fortress at Jianye in 212 to guard his capital: rebuilding the walls restores the tower. |
| 养精蓄锐 | Rest and Recover | Soul of Spring | Spell | 4 | The military maxim of resting troops to restore their strength before battle: each green card lets the general and his flankers recover again. |
| 临江祓禊 | River Purification | Cleansing Rite | Spell | 4 | The Han spring rite of 祓禊, bathing at the riverside to wash away misfortune, cleanses a general of enemy effects. |
| 卑辞骄敌 | Lull with Flattery | Caught Unprepared | Spell | 4 | Lu Xun sent Guan Yu humble, flattering letters until he dropped his guard at Jingzhou: the general is frozen until he takes up arms again. |
| 偷梁换柱 | Swap the Beams | Steal Strength | Spell | 4 | One of the Thirty-Six Stratagems: secretly take the supports from one side and give them to another. |
| 江南瘴疠 | Southern Miasma | Corrosive Mist | Spell | 5 | At Red Cliffs Cao Cao's northern army fell sick in the damp southern air. The miasma rots every piece of gear on the field. |
| 长江天堑 | The Yangtze Barrier | Divine Intervention | Spell | 5 | The Yangtze was Wu's natural moat (天堑), which no northern army could cross: for one round nothing can harm your side. |
| 疑城退敌 | Phantom Ramparts | Intimidation | Spell | 5 | In 224 Xu Sheng raised hundreds of li of false walls along the Yangtze overnight, and Cao Pi's army turned back in alarm: any unit, heroes included, is forced to another lane. |
| 水土不服 | Ill-Suited to the South | Curse of Atrophy | Spell | 6 | In the novel Cao Cao's northern generals cannot adapt to southern water and climate: every enemy general is permanently weakened. |
| 指囷相赠 | Granary Gift | Hand of God | Spell, signature of 鲁肃 | 7 | Lu Su's signature. He pointed to one of his two granaries and gave it all to Zhou Yu's hungry troops (三国志 鲁肃传): his generosity restores the whole army. |
| 天命所归 | Mandate of Heaven | Divine Purpose | Spell | 7 | The one Heaven favours cannot be harmed: an expensive, permanent immunity, Wu's claim to the throne. |

### 兵卒 Creeps (12)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 丹阳兵 | Danyang Diehards | Vhoul Martyr | Creep 2/0/2 | 2 | Danyang was famed for fierce recruits who fought to the death; their sacrifice hardens everyone who survives. |
| 祖茂 | Zu Mao | Rebel Decoy | Creep 2/0/3 | 3 | When Hua Xiong routed Sun Jian, his officer Zu Mao put on Sun Jian's red headscarf to draw off the pursuers (三国志 孙坚传): he swaps places with an ally. |
| 吴越铸师 | Wu-Yue Armorsmith | Smeevil Blacksmith | Creep 2/0/2 | 4 | Wu and Yue were famed for metalwork since the legendary smiths Gan Jiang and Mo Ye: the smith reinforces a general's armour on arrival. |
| 吴钩剑客 | Wu Hook Duelist | Satyr Duelist | Creep 3/0/5 | 4 | The curved Wu hook (吴钩) was Jiangdong's famous blade: the duelist grows deadlier with every fight. |
| 山越蛮兵 | Shanyue Berserkers | Rampaging Hellbear | Creep 2/0/3 | 4 | The Shanyue hill peoples fought Wu for generations and were then drafted into its armies: wild, and fiercer with each battle. |
| 陆家部曲 | Lu Clan Retainers | Roseleaf Druid | Creep 2/0/6, signature of 陆逊 | 4 | Lu Xun's signature. The Lu were one of Wu's four great clans (顾陆朱张), and their private retainers fed and manned the war effort: extra Command every round. |
| 越巫 | Yue Shaman | Selfish Cleric | Creep 4/0/4 | 4 | The shamans of the old Yue lands were known for healing rites; this one heals only itself after each fight. |
| 漕船队 | Grain Barge Fleet | Revtel Convoy | Creep 0/0/20 | 5 | Wu's wealth moved along its rivers and canals by barge: the richer your treasury, the harder the convoy hits. Zero base attack and 20 health suit a cargo fleet. |
| 无难军 | Wunan Guard | Champion of the Ancient | Creep 2/0/6 | 7 | Wu's elite palace troops (无难督), whose name means 'no danger': the more enemies on the field, the stronger they arrive. |
| 杏林医仙 | Apricot Grove Healer | Roseleaf Rejuvenator | Creep 7/0/7 | 7 | Dong Feng, a physician of the Wu lands, asked cured patients to plant apricot trees instead of paying, which gave Chinese medicine the name 杏林: a healer who mends the walls on arrival. |
| 诸葛瑾 | Zhuge Jin | Emissary of the Quorum | Creep 1/2/10 | 8 | Zhuge Liang's elder brother was Wu's patient envoy to Shu who kept the alliance alive: a frail emissary who strengthens the whole side every round. Not one of the reserve heroes. |
| 飞云大船 | Feiyun Flagship | Thunderhide Alpha | Creep 25/0/25 | 9 | 飞云 was the name of one of Sun Quan's real giant warships, larger even than the mapped Tower Ship: a plain 25/25 behemoth for 9 mana. |

### 营建 Improvements (8)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 江防烽燧 | River Beacons | Unearthed Secrets | Improvement | 3 | Wu lined the Yangtze with beacon towers to report attacks: when your tower is hit, word reaches you as a card. |
| 鱼米之乡 | Land of Fish and Rice | Path of the Dreamer | Improvement | 3 | Jiangnan's rice paddies and fisheries, opened up under Wu, fed its walls and garrisons: each green card brings in supplies that restore the tower. |
| 水师操练 | Fleet Drills | Mist of Avernus | Improvement | 3 | Constant naval drilling made Wu's marines the best on the river: the whole army grows stronger every round. |
| 以逸待劳 | Wait Out the Weary | Homefield Advantage | Improvement | 4 | Lu Xun's strategy at Yiling: let the invader exhaust himself on your ground. Each round one tired enemy cannot attack. |
| 定都建业 | Capital at Jianye | Selemene's Favor | Improvement | 4 | Sun Quan made Jianye (modern Nanjing) his seat and later his imperial capital: a lasting centre of command. |
| 伤兵营 | Field Infirmary | Altar of the Mad Moon | Improvement | 4 | Artifact's Melee Creep is the mapped 步卒 token: a field infirmary keeps the common infantry patched up. |
| 吉人天相 | Heaven Protects | Cheating Death | Improvement | 4 | An idiom for the fortunate escaping certain death, as Sun Quan repeatedly did; a green general must be present to call down that luck. |
| 二乔宅 | Qiao Sisters' Manor | Verdant Refuge | Improvement, signature of 大乔 | 5 | Da Qiao's signature. The sisters' family home at Wan (皖城, modern Qianshan) is still shown with its rouge well: a guarded sanctuary that shelters the whole side. |

## 群 Qun (black)

### 武将 Heroes (10)

| 中文名 | English | original Valve card | type | cost | ability | signature | rationale |
|---|---|---|---|---|---|---|---|
| 貂蝉 | Diaochan | Winter Wyvern | Hero 6/0/6 | - | 闭月（主动2） | 离间 Estrangement | Winter's Curse makes a unit's own allies attack it, which is Diaochan setting Lü Bu against Dong Zhuo (三国杀 离间). 闭月 (her 'moon hides its face' epithet) becomes the slip-into-position strike. |
| 董卓 | Dong Zhuo | Bloodseeker | Hero 7/0/7 | - | 暴虐（被动） | 酒池肉林 Wine Pools, Meat Forests | A bloodthirsty brute who feeds on kills fits the tyrant (三国杀 暴虐 / 酒池 / 肉林). A drunk, silenced berserker is his signature 酒池肉林. |
| 袁绍 | Yuan Shao | Bounty Hunter | Hero 7/0/7 | - | 乱击（被动） | 讨曹檄文 Proclamation Against Cao | Yuan Shao was rich and indecisive, so a coin-flip attack boost suits him; 乱击 (random arrow volleys) is his 三国杀 skill. Chen Lin's proclamation for him put a price on Cao Cao's head, which is the bounty signature. |
| 张角 | Zhang Jiao | Tinker | Hero 7/0/5 | - | 雷击（主动3） | 黄天当立 Yellow Heaven Rises | Zhang Jiao is the Yellow Turban sorcerer who calls down lightning (三国杀 雷击). Charge-by-charge uprising waves that hit every enemy and the tower suit his slogan 苍天已死，黄天当立. |
| 孟获 | Meng Huo | Lich | Hero 5/0/9 | - | 祭旗（主动2） | 七擒七纵 Seven Captures | The Nanman king spends his tribes freely before battle (祭旗). He was captured and freed seven times and came back every time, which is the seven-times-repeating Chain Frost signature 七擒七纵. |
| 祝融 | Lady Zhurong | Sniper | Hero 5/0/6 | - | 飞刀（主动3） | 火神之刃 Blade of the Fire God | In 演义 ch.89 Lady Zhurong fights with thrown flying knives, the ranged burst of a sniper. She claims descent from the fire god Zhurong, which names the any-lane execution signature. |
| 孙坚 | Sun Jian | Sorla Khan | Hero 8/0/6 | - | 破虏（被动） | 先登洛阳 First into Luoyang | Faction move Wu to Qun. Sun Jian died in 191, before Wu existed, as a coalition warlord under Yuan Shu against Dong Zhuo, and was first into Luoyang, so he is the tower-breaker. 破虏 is from his title 破虏将军. Avoids the mapped 江东猛虎. |
| 华佗 | Hua Tuo | Necrophos | Hero 5/0/6 | - | 五禽戏（被动） | 麻沸散 Mafei Powder | Necrophos is a plague doctor and Hua Tuo the legendary physician. His 五禽戏 exercises build his vitality, and his 麻沸散 anaesthetic numbs every enemy beside the hero. Avoids the mapped 刮骨疗毒. |
| 左慈 | Zuo Ci | Lion | Hero 6/0/5 | - | 遁甲天书（主动4） | 掷杯戏曹 Toying with Cao Cao | Zuo Ci, the Daoist magician who received the 遁甲天书 in 演义 ch.68, casts the big piercing spell. In the same chapter he mocks Cao Cao at his own feast (掷杯戏曹), so his signature steals the enemy's resources. |
| 高顺 | Gao Shun | Storm Spirit | Hero 4/0/6 | - | 攻无不破（被动） | 急袭小沛 Raid on Xiaopei | 英雄记 says Gao Shun's unit 'broke every position it attacked' (所攻无不破). His 198 strike that took Xiaopei from Liu Bei is the any-lane hero reposition signature. Avoids the mapped 陷阵营. |

### 计策 Spells (19)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 流矢 | Stray Arrow | Grazing Shot | Spell | 1 | Stray arrows (流矢) fell officers all through the chronicles of the era: a cheap, small hit that can land in any lane. |
| 追亡逐北 | Hunt the Fleeing | Relentless Pursuit | Spell | 1 | The classical phrase for running down a beaten foe: a warlord crosses lanes to chase its prey and wounds it. |
| 掷杯戏曹 | Toying with Cao Cao | Mana Drain | Spell, signature of 左慈 | 2 | Zuo Ci's signature. At Cao Cao's own feast (演义 ch.68) he conjures fish and dragon's liver, empties the wine and flings the cup: he takes the host's resources for himself. |
| 临阵倒戈 | Spears Turned Inward | Lodestone Demolition | Spell | 3 | In the late-Han chaos armoured guards turned on their own masters again and again (Lü Bu on Ding Yuan, then on Dong Zhuo). The better armed the enemy's men, the worse the damage when they turn on their own walls. |
| 纵火焚营 | Torch the Works | Dirty Deeds | Spell | 3 | Saboteurs set fire to the enemy's fortifications, and the more works there are, the bigger the fire. |
| 铸小钱 | Debased Coinage | Payday | Spell | 3 | 三国志 董卓传: Dong Zhuo melted down bronze statues and minted flimsy small coins, multiplying the money supply overnight. |
| 讨曹檄文 | Proclamation Against Cao | Track | Spell, signature of 袁绍 | 3 | Yuan Shao's signature. Chen Lin's proclamation for Yuan Shao promised a marquisate and fifty million cash for Cao Cao's head: a price on the target until it dies. |
| 急袭小沛 | Raid on Xiaopei | Ball Lightning | Spell, signature of 高顺 | 3 | Gao Shun's signature. In 198 Lü Bu sent Gao Shun and Zhang Liao to strike Liu Bei at Xiaopei, and they took it: a sudden reposition into any lane. |
| 麻沸散 | Mafei Powder | Heartstopper Aura | Spell, signature of 华佗 | 4 | Hua Tuo's signature, the name the mapping reserved for him. His anaesthetic's numbing vapour hangs around the hero and slowly stops the hearts of anyone beside him. |
| 酒池肉林 | Wine Pools, Meat Forests | Blood Rage | Spell, signature of 董卓 | 4 | Dong Zhuo's signature, after his 三国杀 skills 酒池 and 肉林: drunk on excess, the unit loses its abilities but strikes far harder. |
| 截断粮道 | Cut the Supply Line | Arcane Censure | Spell | 4 | Severing the grain road was the period's standard way to cripple an army for good: the enemy loses 1 Command permanently. |
| 岘山伏击 | Ambush at Mount Xian | Gank | Spell | 4 | Huang Zu's archers lay in wait at Mount Xian and cut down Sun Jian as he rode ahead alone: a lone target dragged into a fight on the ambusher's terms, from any lane. |
| 衣带诏 | Belt Edict | Murder Plot | Spell | 4 | Emperor Xian's secret edict, sewn into a jade belt, named the man to kill and armed the conspirators: a big strike at a chosen target. |
| 十八路诸侯 | Eighteen Lords | Coordinated Assault | Spell | 4 | The coalition of eighteen lords against Dong Zhuo (演义 ch.5): each new scheme rallies the lord and the allies beside him. |
| 纵兵劫掠 | Let Them Plunder | Collateral Damage | Spell | 4 | Li Jue and Guo Si turned their troops loose on Chang'an: a warlord whose army plunders does lasting damage to cities. |
| 离间 | Estrangement | Winter's Curse | Spell, signature of 貂蝉 | 6 | Diaochan's signature. 离间 is her 三国杀 skill: she set Lü Bu against Dong Zhuo, so an enemy's own men turn on it. |
| 火神之刃 | Blade of the Fire God | Assassinate | Spell, signature of 祝融 | 7 | Lady Zhurong's signature. 演义 ch.90 calls her a descendant of the fire god Zhurong; her longest throw is a killing blade that reaches any lane. |
| 七擒七纵 | Seven Captures | Chain Frost | Spell, signature of 孟获 | 7 | Meng Huo's signature. Captured and freed seven times, he came back every time: the strike that lashes the line again and again (7 repeats) is his seven returns. |
| 衔枚夜袭 | Silent Night Raid | The Cover of Night | Spell | 7 | Night raiders bit wooden gags (衔枚) to march in silence: the hero slips unseen into another lane and falls on the walls. |

### 兵卒 Creeps (10)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 游侠儿 | Young Knight-Errant | Assassin's Apprentice | Creep 3/0/2 | 2 | Han 游侠 youths sold their swords to settle other men's feuds: a cheap creep that picks its own target. |
| 投石兵 | Stone Slingers | Oglodi Catapult | Creep 0/0/4 | 2 | Hill bandits hurled stones from slings over the walls day after day: no attack of their own, only steady piercing damage to the tower. (发石车 is avoided because it is the same machine as the mapped 霹雳车.) |
| 太平道人 | Taiping Preacher | Disciple of Nevermore | Creep 4/-2/4 | 3 | Taiping preachers handed out talisman water (符水) and promised believers they could not be harmed, so the faithful charged recklessly. |
| 小黄门 | Palace Eunuch | Tyler Estate Censor | Creep 2/0/8 | 4 | Palace eunuchs held back and buried memorials, choking the court's orders: a durable body with little attack that drains enemy Command. |
| 哀兵 | Grieving Host | Pit Fighter of Quoidge | Creep 2/0/8 | 4 | 哀兵必胜: an army mourning its dead fights harder. It gains attack each time a neighbouring ally falls. |
| 白波贼 | White Wave Bandits | Oglodi Vandal | Creep 4/0/4 | 4 | The Baibo bandits of Hedong raided towns on sight: they arrive and damage the tower immediately. |
| 饥军 | Starving Horde | Ravenous Mass | Creep 1/0/1 | 4 | Famine armies of the era swallowed their own (the chronicles record 人相食): it consumes its neighbours and takes on their strength. |
| 赵娥 | Zhao E the Avenger | Sister of the Veil | Creep 4/0/5 | 5 | Zhao E (三国志 庞淯传 注, 列女传) waited years, then killed her father's murderer in broad daylight: a creep that picks its own target. |
| 黑山贼 | Black Mountain Raider | Ravenhook | Creep 3/0/6 | 6 | Zhang Yan's Black Mountain bandits stripped travellers and armies and sold the loot: the blocker's gear becomes gold. |
| 许贡门客 | Xu Gong's Avengers | Assassin's Shadow | Creep 15/0/5 | 7 | Xu Gong's retainers hid in the wilds and struck Sun Ce down while he hunted apart from his guard: deadly alone, weaker the more allies are around. |

### 营建 Improvements (14)

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 冲车 | Battering Ram | Trebuchets | Improvement | 1 | A roofed ram that pounds the gate every round: steady piercing tower damage. |
| 走为上 | Retreat Is Best | Escape Route | Improvement | 1 | The last of the Thirty-Six Stratagems, 走为上 (when all else fails, run), was the warlords' constant fallback: pull a hero safely back to camp. |
| 二袁交恶 | Feud of the Yuans | Bitter Enemies | Improvement | 2 | The half-brothers Yuan Shao and Yuan Shu let their feud simmer until it wrecked both houses: a countdown, then both towers burn. |
| 地道 | Sapper Tunnels | Unsupervised Artillery | Improvement | 2 | Yuan Shao's sappers tunnelled under Yijing and at Guandu. Digging only works when no free enemy can stop it. |
| 玉石俱焚 | Jade and Stone Burn | Assured Destruction | Improvement | 3 | The idiom for total mutual ruin, jade and common stone burning together: every hero on both sides becomes a wall-breaker. |
| 诡道 | Way of Deception | Path of the Cunning | Improvement | 3 | Sun Tzu: 兵者，诡道也 (all warfare is deception). Each black scheme sharpens a random ally against the walls. |
| 郿坞 | Mei Fortress | Revtel Investments | Improvement | 3 | Dong Zhuo stockpiled thirty years of grain and treasure at Mei, and it was emptied the day he fell: it hoards round by round and cashes out once. |
| 西园卖官 | Offices for Sale | Iron Fog Goldmine | Improvement | 3 | Emperor Ling sold official posts at the Western Garden, a steady stream of money: gold every round. |
| 先登洛阳 | First into Luoyang | Assault Ladders | Improvement, signature of 孙坚 | 3 | Sun Jian's signature. In 191 his army was first into Luoyang after beating Dong Zhuo's forces: his whole army hits walls harder. |
| 歃血为盟 | Blood Oath | The Oath | Improvement | 3 | The lords at Suanzao smeared their lips with blood and swore to fight Dong Zhuo. Once sworn there is no more scheming, only battle under a warlord. |
| 十常侍 | Ten Attendants | The Tyler Estate | Improvement | 4 | The Ten Attendants' corruption paralysed the whole Han government: both sides lose Command. |
| 床弩 | Bed Crossbow | Keenfolk Turret | Improvement | 4 | Frame-mounted heavy crossbows guarded Han ramparts: a small piercing shot every round. |
| 黄天当立 | Yellow Heaven Rises | March of the Machines | Improvement, signature of 张角 | 5 | Zhang Jiao's signature. His rebellion rose under the slogan 苍天已死，黄天当立: wave after wave of uprisings strike every enemy and the tower until the charges run out. |
| 井阑 | Siege Tower | Steam Cannon | Improvement | 7 | At Guandu Yuan Shao's towering archery platforms let archers shoot anywhere into Cao's camp: a heavy cross-lane piercing shot. |

## 军备 Items

| 中文名 | English | original Valve card | type | cost | rationale |
|---|---|---|---|---|---|
| 杜康酒 | Du Kang Wine | Fountain Flask | Item (Consumable) | 4金 | Cao Cao's 短歌行: '何以解忧？唯有杜康'. The legendary wine cures every care, so it fully restores a unit. |
| 绝影 | Jueying Steed | Assassin's Veil | Item (Accessory) | 4金 | Cao Cao's horse 'Shadowless' carried him out of the Wancheng ambush. A mount (坐骑 slot) that lets its rider pick whom to charge. |
| 丹书铁券 | Iron Pardon Tablet | Revtel Signet Ring | Item (Accessory) | 4金 | The Han iron tablet inscribed in cinnabar that pardoned its holder: with a lower price on his head, the hero is worth less gold to the enemy. |
| 战鼓 | War Drums | Ristul Emblem | Item (Accessory) | 4金 | The war drum drives both sides into reckless close combat (一鼓作气), so the hero and its blocker both drop their guard. |
| 爪黄飞电 | Flying Lightning | Phase Boots | Item (Accessory) | 5金 | Cao Cao's white horse with yellow hooves from the Xutian hunt (演义 ch.20); its lightning speed swaps the rider's place in the line. |
| 大宛马 | Ferghana Horse | Stonehall Cloak | Item (Accessory) | 5金 | The 'heavenly horses' of Dayuan, prized across the Han for stamina that grew with every campaign: the mount gains health after each combat. |
| 蒺藜甲 | Caltrop Mail | Barbed Mail | Item (Armor) | 5金 | Iron caltrops (铁蒺藜) were standard Han field defences; armour studded with them hurts whoever strikes it. |
| 流星锤 | Meteor Hammer | Demagicking Maul | Item (Weapon) | 5金 | The chained meteor hammer hurled by Wang Shuang in 演义 ch.97. Swung freely when no one blocks its wielder, it smashes an enemy fortification. |
| 百辟刀 | Hundred-Forged Blade | Stonehall Pike | Item (Weapon) | 5金 | Cao Cao's 百辟刀令 records blades folded and forged a hundred times; every battle tempers it further. |
| 明光铠 | Bright Light Armor | Stonehall Plate | Item (Armor) | 5金 | The mirror-plated armour Cao Zhi lists among imperial gifts (先帝赐臣铠表): each battle polishes and reinforces it. |
| 干将莫邪 | Ganjiang and Moye | Jasper Daggers | Item (Weapon) | 5金 | The legendary paired swords forged by the Wu smiths Gan Jiang and Mo Ye: their edges pass through armour, and taking them up throws off the enemy's hold. (双股剑 is Liu Bei's hero ability.) |
| 锦袍 | Brocade Robe | Fur-lined Mantle | Item (Accessory) | 6金 | Cao Cao gave Guan Yu a brocade battle robe, which he wore under Liu Bei's old green one (演义 ch.25): a plain +8 health. |
| 鱼鳞甲 | Fish-Scale Armor | Chainmail | Item (Armor) | 6金 | Overlapping iron scale armour, one step up from the mapped hide armour: the standard mid-tier body armour. |
| 诸葛连弩 | Zhuge Crossbow | Keenfolk Musket | Item (Weapon) | 6金 | The repeating crossbow credited to Zhuge Liang is the era's 'firearm': it replaces the musket and shoots a unit for 2. |
| 倚天剑 | Yitian Sword | Blink Dagger | Item (Weapon) | 7金 | Cao Cao's 'Heaven-Reliant' sword, twin of the mapped 青釭剑: its bearer goes wherever the battle needs him. |
| 古锭刀 | Guding Blade | Blade of the Vigil | Item (Weapon) | 7金 | Sun Jian's heavy saber in 演义, also a 三国杀 weapon: its wide cuts reach the units beside the target. |
| 舍命甲 | Death-Sworn Armor | Bracers of Sacrifice | Item (Armor) | 8金 | Every warlord kept 死士, warriors sworn to die: the wearer takes those beside him down with him. |
| 环首刀 | Ring-Pommel Saber | Poaching Knife | Item (Weapon) | 8金 | The ordinary Han ring-pommel saber, the soldier's tool for taking heads and claiming the rewards for them: gold on kills. |
| 大橹 | Great Pavise | Shield of Basilius | Item (Armor) | 8金 | The 橹 was the Han army's great standing shield (说文: 橹，大盾也), covering the men beside its bearer as well. |
| 筒袖铠 | Sleeved Armor | Keenfolk Plate | Item (Armor) | 8金 | Zhuge Liang's improved 筒袖铠, recorded as stopping even heavy crossbow bolts: the more foes press in, the better it holds. |
| 火油 | Fire Oil | Obliterating Orb | Item (Consumable) | 9金 | Fire attack (火攻) is the era's answer to fortifications: a jar of oil burns one improvement to the ground. |
| 通关文牒 | Border Pass | Golden Ticket | Item (Consumable) | 9金 | Guan Yu had to cut through five passes because he lacked a travel pass. With one, every gate opens, including the black market's. |
| 白银狮子 | Silver Lion Armor | Rumusque Vestments | Item (Armor) | 9金 | In 三国杀 白银狮子 is the armour that blunts damage and restores health: armour with a healing active. |
| 贯石斧 | Stone-Splitting Axe | Red Mist Maul | Item (Weapon) | 9金 | Xu Huang's great axe, a 三国杀 weapon whose name means it bites through stone: big siege for battering towers. |
| 太平要术 | Way of Great Peace | Ring of Tarrasque | Item (Accessory) | 10金 | Zhang Jiao's heavenly book, whose talisman water healed the sick and drew millions to the Yellow Turbans: large regeneration. |
| 孟德新书 | Mengde's New Book | Cloak of Endless Carnage | Item (Accessory) | 10金 | Cao Cao's military manual, written from hard battlefield experience (Zhang Song famously recited it): every fallen comrade adds a lesson. |
| 招魂幡 | Soul-Calling Banner | Book of the Dead | Item (Accessory) | 10金 | The 招魂 rite called the souls of the dead back; this banner calls fallen Foot Soldiers back as Ghost Soldiers (the Zombie token). 遁甲天书 is left to Zuo Ci's hero ability. |
| 浑天仪 | Armillary Sphere | Claszureme Hourglass | Item (Accessory) | 10金 | Zhang Heng's Eastern Han armillary sphere read the turning of the heavens; its keeper foresees and delays the enemy's plans. |
| 玄武盾 | Black Tortoise Shield | Shield of Aquila | Item (Armor) | 10金 | The Black Tortoise, guardian of the north and symbol of impenetrable defence: the rare, stronger shield aura. |
| 赤兔 | Red Hare | Hero's Cape | Item (Accessory) | 12金 | '人中吕布，马中赤兔.' Red Hare, the greatest mount of the age, is the strongest pure-survivability accessory: double any other mount. |
| 玄甲 | Black Iron Armor | Platemail | Item (Armor) | 12金 | Full suits of heavy armour were rare: Cao Cao wrote that he had twenty against Yuan Shao's ten thousand. Dark iron 玄甲 is that top-tier plain armour. |
| 仁王盾 | Benevolent King Shield | Seraphim Shield | Item (Armor) | 13金 | In 三国杀 仁王盾 makes black attacks fizzle: a benevolent ruler's shield that blunts every blade on the field. |
| 狮盔 | Lion Helm | Shiva's Guard | Item (Armor) | 16金 | Ma Chao's terrifying lion helm and beast belt (狮盔兽带, 演义 ch.58): the sight of it unnerves a whole enemy formation for good. |
| 紫金冠 | Purple-Gold Crown | Helm of the Dominator | Item (Armor) | 19金 | Lü Bu's 束发紫金冠 is the iconic helm of 演义; its awe makes enemy troops change sides, as men so often did in the chaos. |
| 龙袍 | Dragon Robe | Vesture of the Tyrant | Item (Armor) | 19金 | The imperial robe that Yuan Shu and others grasped at: its authority fortifies the tower and calls its wearer back to the field at once. |
| 丈八蛇矛 | Serpent Spear | Wingfall Hammer | Item (Weapon) | 19金 | Zhang Fei's eighteen-foot serpent spear (Zhang Fei is the mapped Axe): its bearer's ferocity steadies the comrades at his side. |
| 传国玉玺 | Imperial Jade Seal | Shop Deed | Item (Deed) | 22金 | The Heirloom Seal that Sun Jian found in Luoyang and Yuan Shu coveted. Whoever holds it commands the realm's treasures: every Secret Shop item becomes free. |
| 虎符 | Tiger Tally | Horn of the Alpha | Item (Accessory) | 25金 | The split bronze tiger tally authorised the mobilisation of troops; matching its halves calls up a Tower Ship (the mapped Thunderhide Pack). |
| 八门金锁 | Eight-Gate Lock | Nyctasha's Guard | Item (Armor) | 25金 | Cao Ren's 八门金锁阵 (演义 ch.36), a formation that swallows attackers and spits them out elsewhere: a defensive formation-armour that scatters adjacent enemies. |
| 方天画戟 | Sky Piercer | Apotheosis Blade | Item (Weapon) | 25金 | Lü Bu's painted halberd, reserved by the mapping for the top-tier weapon: at 25 gold the most devastating weapon in the game, cutting down anything it touches. |

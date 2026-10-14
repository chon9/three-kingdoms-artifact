# Three Kingdoms card art, full catalog: ChatGPT image prompts

This file holds **219 ready-to-paste prompts** for the rest of the card catalog: 95 spells, 37 creeps, 39 improvements, 40 items and 5 tokens, plus **3 hero portraits to regenerate** because those heroes changed faction. Numbering continues from [`ART_PROMPTS.md`](ART_PROMPTS.md), which ends at #111. The same prompts are in [`art_prompts_catalog.csv`](art_prompts_catalog.csv) (UTF-8, opens in Excel).
The 38 catalog heroes already have portraits in `assets/art/heroes_reserve/`; they only need copying to their card paths (see *Hero art copy table* at the end).

Every prompt is complete: subject, framing rule, faction line, style block, negative line and size. The framing, faction, style and negative lines are copied word for word from the style bible in `ART_PROMPTS.md`, so these cards match the 111 you already made.

## How to use it

The workflow is the same as in [`ART_PROMPTS.md`](ART_PROMPTS.md#how-to-use-it): read its crop check, consistency tips and licensing notes first.

1. **One batch per ChatGPT session.** Start a fresh chat for each batch, and start another fresh chat if the style drifts.
2. At the start of each session, attach your accepted **Guan Yu** image (the style anchor) and add the line *"Match the rendering style, palette and brushwork of the attached image."*
3. Copy one prompt (the grey block under each entry) and send it. If ChatGPT returns a square, reply "make it 1024x1536 portrait".
4. **Signature cards**: attach the hero portrait named in the entry's note so the face matches. Other notes name extra references (for example the Cao Cao card art) where a known figure appears.
5. Check the crop and make sure there is no writing anywhere. Regenerate, or fix it with ChatGPT's edit (select area) tool.
6. Download the PNG and save it under the exact path shown in the entry heading, for example `assets/art/cards/kraken_shell.png`. The file name is the card's Valve card id.
7. Before committing, run `python tools/optimize_art.py`, then open the project in Godot once so it creates the `.import` files, and commit those with the images.

### Order of generation

1. **Hero portraits to regenerate (#328-#330)** before the batch that holds their signature card: 孙尚香 before Batch 1, 陈宫 before Batch 2, 孙坚 before Batch 4.
2. **Batches 1-4**, one faction per session. Within a batch the order is spells, creeps, improvements; signature cards can be made right after you attach their hero.
3. **Batch 5 (items)** in its own session: objects only, no hands or people. The four horses use the Dilu framing line.
4. **Batch 6 (tokens)** whenever you like. If you want a summoned token to match the card that summons it, make the token first (the notes say which).

### Batches

| Batch | Numbers | Spells | Creeps | Improvements | Items | Tokens | Total |
|---|---|---|---|---|---|---|---|
| Batch 1 - Shu (red) | 112-155 | 26 | 11 | 7 |  |  | 44 |
| Batch 2 - Wei (blue) | 156-197 | 28 | 4 | 10 |  |  | 42 |
| Batch 3 - Wu (green) | 198-239 | 22 | 12 | 8 |  |  | 42 |
| Batch 4 - Qun (black) | 240-282 | 19 | 10 | 14 |  |  | 43 |
| Batch 5 - Items | 283-322 |  |  |  | 40 |  | 40 |
| Batch 6 - Tokens | 323-327 |  |  |  |  | 5 | 5 |
| Hero portraits to regenerate | 328-330 | | | | | | 3 |
| **Total** | 112-330 | | | | | | **219** |

### Framing used

- **Spells and improvements**: the spell framing line (scene, action in the upper 60%).
- **Creeps and tokens**: the heroes-and-units figure line. Exceptions: 漕船队 and 飞云大船 use the Tower Ship line, and 拒马 (Spiked Barricade) uses the item line.
- **Items**: the item line, with the neutral gold faction line. The horses 绝影, 爪黄飞电, 大宛马 and 赤兔 use the Dilu horse line.

## Batch 1 - Shu (red) (44)

**Shu (red) - Spells (26)**

### 112. 耒阳断案 / Leiyang Verdicts — `assets/art/cards/kraken_shell.png`

*Card:* Permanently give a red hero +1 armor. Get initiative.  
*Note:* Signature card of 庞统 Pang Tong: attach `assets/art/heroes_reserve/pangtong.png` as a reference so the face matches.

```text
Pang Tong, the plain-faced, unkempt strategist with bushy brows and a scruffy beard, lounging at a county magistrate's bench with a wine cup in one hand and a brush flicking in the other, clearing a hundred days of backlog in a single afternoon. Clerks rush stacks of bamboo case-files past him in a blur while relieved petitioners bow. A thin shell of golden light settles over his shoulders like armour, and he is visibly a half-beat ahead of everyone in the room. All slips and files are blank, with no writing. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 113. 九伐中原 / Nine Northern Campaigns — `assets/art/cards/double_edge.png`

*Card:* Give a red hero +8 attack and -8 armor this round.  
*Note:* Signature card of 姜维 Jiang Wei: attach `assets/art/heroes_reserve/jiangwei.png` as a reference so the face matches.

```text
Jiang Wei leading a thin crimson column at full charge down a snowy mountain road toward dark Wei fortresses in the valley, spear levelled and red cloak torn. Fierce red fire blazes along his spear and arms, but his armour is cracked and shedding plates as he rides, all offence and no defence, and his own camp lies almost empty on the ridge behind him. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 114. 拖刀计 / Trailing-Blade Feint — `assets/art/cards/poised_to_strike.png`

*Card:* Give a red hero +4 attack this round.  
*Note:* Guan Yu's trailing-blade trick: attach the Guan Yu card art (keefe) if you want the rider to read as him.

```text
A Shu cavalry general in crimson armour turned backward in the saddle mid-gallop, feigning flight: his long blade drags low behind him, its edge glowing hot red as it begins to sweep upward at a pursuing enemy rider who has leaned in too close. A plume of dust and low sunset light run along the blade. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 115. 张松献图 / Zhang Song's Map — `assets/art/cards/new_orders.png`

*Card:* Choose an ally. Choose a combat target for it.  

```text
Zhang Song, a small, homely but sharp-eyed official, unrolling a long painted map of mountain roads, passes and fortresses (pictures only, no writing) across a candlelit table. One finger stabs down at a single fortress, and the Shu officers in crimson leaning over the table all follow his finger to the chosen target. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 116. 傅彤断后 / Fu Tong's Rearguard — `assets/art/cards/fight_through_the_pain.png`

*Card:* Give a red hero +2 armor this round. Get initiative.  

```text
Fu Tong, a lone wounded Shu officer, standing his ground on a burning mountain road with his spear held crosswise across the narrow path. A pale golden barrier of light shimmers around his body as a dark enemy host pours toward him, while the fleeing red banners of his own army vanish into the smoke behind him. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 117. 七进七出 / Seven Charges Through — `assets/art/cards/whirling_death.png`

*Card:* Choose an allied red hero. Deal 2 damage to its enemy neighbors and give them -2 attack this round.  
*Note:* Signature card of 赵云 Zhao Yun: attach `assets/art/heroes_reserve/zhaoyun.png` as a reference so the face matches.

```text
Zhao Yun in silver-white armour with crimson trim, the swaddled infant safe against his chest, carving a path through a dense ring of enemy spearmen with one sweeping arc of his silver spear. The soldiers on both sides of him reel back, struck and dazed, their weapons sagging, as a silver arc of light traces the sweep. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 118. 廖化先锋 / Liao Hua Leads — `assets/art/cards/heroic_resolve.png`

*Card:* Permanently give a red hero "After you play a non-item card costing 2 or less, permanently give this hero +2 health."  

```text
The grizzled veteran Liao Hua, scarred and grey-bearded in battered crimson armour, planting his spear at the head of a thinning column. Young recruits step up to his side one by one, and each one sends a small pulse of warm red light into him, so the old man stands taller and sturdier than his years. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 119. 夜战葭萌关 / Night Duel at Jiameng — `assets/art/cards/duel.png`

*Card:* Choose an allied red hero and another unit. They battle each other.  
*Note:* Signature card of 马超 Ma Chao: attach `assets/art/heroes_reserve/machao.png` as a reference so the face matches. Also attach Zhang Fei (axe) for his opponent.

```text
Ma Chao in his silver lion-head helm and white armour clashing spears with Zhang Fei, a black-bearded giant in dark iron, by torchlight before a mountain-pass gate. Their spears lock in a shower of sparks while rows of soldiers on both sides hold up torches in a ring around the duel. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 120. 骂死王朗 / Scolding Wang Lang — `assets/art/cards/pick_a_fight.png`

*Card:* Choose an allied hero. It taunts. Choose a combat target for it.  
*Note:* Attach the Zhuge Liang portrait (zhugeliang.png). Show the minister falling, no blood.

```text
Two armies face each other across a plain while Zhuge Liang, in white Daoist robes, sits on a small four-wheeled cart and points his feather fan scornfully at an old white-bearded Wei minister, who clutches his chest and topples from his horse. Every soldier in the enemy line has turned to stare at the cart. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 121. 虎父无犬子 / Tiger's Cubs — `assets/art/cards/rising_anger.png`

*Card:* Permanently give a red hero "After you play a non-item card costing 2 or less, permanently give this hero +1 attack."  

```text
Two young Shu warriors, Guan Xing with a green-tasselled crescent glaive and Zhang Bao with a serpent spear, charging shoulder to shoulder beneath fluttering white mourning ribbons. Faint ghostly silhouettes of their fathers watch from the clouds above, and the young men's weapons burn brighter with every stride. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 122. 智取瓦口 / Taking Wakou Pass — `assets/art/cards/smash_their_defenses.png`

*Card:* Condemn an improvement. Draw a card.  

```text
Shu soldiers in red scrambling over a mountain pass and pulling down a burning wooden gate-fort with ropes and hooks, its timbers collapsing in flame. A hidden goat path winds up the cliff behind them, and a scout in front holds up a captured map case. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 123. 法正举旗 / Fa Zheng's Signal — `assets/art/cards/spot_weakness.png`

*Card:* Give a hero and its allied neighbors pierce this round. Draw a card.  

```text
The strategist Fa Zheng on a hilltop raising a plain red signal banner, while below him a line of Shu soldiers led by a white-bearded general surges through a gap in a tired enemy formation, their spears punching straight through the raised shields. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 124. 盘蛇谷 / Coiled Serpent Valley — `assets/art/cards/rend_armor.png`

*Card:* Permanently give a unit -X armor, where X is its armor.  

```text
A winding, serpent-shaped jungle valley seen from the ridge, fire racing along its floor. Southern warriors in glistening woven rattan armour are caught in the flames, and their once-impenetrable armour is burning away and peeling off in blackened sheets. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 125. 镇守汉中 / Hold Hanzhong — `assets/art/cards/enrage.png`

*Card:* Give a red hero +4 attack and +4 armor this round.  
*Note:* Signature card of 魏延 Wei Yan: attach `assets/art/heroes_reserve/weiyan.png` as a reference so the face matches.

```text
Wei Yan, fierce and red-faced, standing on a mountain-pass wall with his heavy blade planted before him and red banners snapping behind, staring down an enormous Wei host that fills the valley below. A blazing crimson aura surrounds him like both a shield and a flame. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 126. 五虎上将 / Five Tiger Generals — `assets/art/cards/clear_the_deck.png`

*Card:* Give allied heroes +4 cleave this round.  
*Note:* Attach Guan Yu (keefe), Zhang Fei (axe) and the Zhao Yun, Ma Chao and Huang Zhong portraits if ChatGPT accepts several references; otherwise attach Guan Yu only.

```text
The Five Tiger Generals of Shu charging side by side in a wedge: Guan Yu with his crescent glaive, Zhang Fei with his serpent spear, Zhao Yun with a silver spear, Ma Chao in a lion helm and the white-bearded Huang Zhong with a bow. Their weapons sweep one wide, shared arc of crimson light that scatters the whole enemy line in front of them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 127. 回马枪 / Turnback Spear — `assets/art/cards/sucker_punch.png`

*Card:* Stun a unit blocking an allied red hero this round. Deal 2 damage to that unit.  

```text
A Shu spearman twisting backward on a galloping horse, his spear thrusting behind him into a startled pursuing rider, who reels in the saddle, stunned, with a starburst of impact light at the spear tip. Dust trails and a red sunset sky. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 128. 兴复汉室 / Restore the Han — `assets/art/cards/tresdins_standards.png`

*Card:* Permanently give a red hero "After you play a red card, give this hero and its allied neighbors +1 attack and +1 armor this round."  

```text
A Shu general raising a great plain crimson war standard on a hilltop at sunrise while the ranks around him lift their weapons in answer. A warm red glow ripples outward from the standard and settles over the soldiers on either side of him like armour. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 129. 烈弓 / Fierce Bow — `assets/art/cards/viscous_nasal_goo.png`

*Card:* Permanently give a unit -2 armor.  
*Note:* Signature card of 黄忠 Huang Zhong: attach `assets/art/heroes_reserve/huangzhong.png` as a reference so the face matches.

```text
The white-bearded veteran Huang Zhong at full draw on a mountain slope. In the distance, a heavy arrow has already punched through an enemy officer's lamellar breastplate, and the armour plates burst apart around the impact, with no blood shown. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 130. 攻心为上 / Win Their Hearts — `assets/art/cards/crippling_blow.png`

*Card:* Permanently give a hero -2 attack.  
*Note:* Attach the Meng Huo and Zhuge Liang portraits.

```text
Meng Huo, the proud southern king, unbound and kneeling on one knee before a Shu camp, his sword lowered to the ground and his head bowed, as Zhuge Liang with his feather fan gestures openly to let him go. The fight has drained out of the king's shoulders. Dignified, not a caricature. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 131. 火烧博望 / Fire at Bowang — `assets/art/cards/raze.png`

*Card:* Condemn all enemy improvements.  
*Note:* Zhuge Liang's first victory; no figures need to be recognisable.

```text
A narrow reed-filled valley at dusk erupting into a wall of flame: enemy palisades, watchtowers, tents and supply wagons all burn together as fire arrows streak down from the dark ridges, where small Shu archers kneel against the sky. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 132. 温酒斩华雄 / Ere the Wine Cools — `assets/art/cards/enough_magic.png`

*Card:* Proceed to the combat phase.  
*Note:* Attach the Guan Yu card art (keefe).

```text
A cup of wine still steaming on a lacquered war-council table in the foreground, while beyond the open tent flap Guan Yu, in a green robe and crimson battle cloak, rides back through the camp gate with his long crescent glaive, the duel already over before the wine has cooled. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 133. 鸡肋 / Chicken Rib — `assets/art/cards/routed.png`

*Card:* Permanently give enemy heroes at the Fountain -X attack, where X is half their attack. Permanently give them "Your tower has -1 mana."  

```text
A dim Wei command tent at night: a bowl of bare chicken ribs sits beside a guttering lamp on the table while weary, deflated Wei officers quietly roll up maps and pack the tents to withdraw. Through the tent opening, Shu red banners and torches crowd the surrounding mountains. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 134. 髀肉之叹 / Lament of Idle Thighs — `assets/art/cards/gods_strength.png`

*Card:* Permanently give a red hero +4 attack.  
*Note:* Signature card of 刘备 Liu Bei: attach `assets/art/heroes_reserve/liubei.png` as a reference so the face matches.

```text
Liu Bei rising from a banquet seat in Jingzhou with tears on his face, gripping his twin swords as he looks out at a red-bannered army forming in the courtyard. His resolve flares as a burning crimson light running down both blades. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 135. 火兽破阵 / Fire Beasts Break Ranks — `assets/art/cards/primal_roar.png`

*Card:* Stun a unit blocking an allied red hero this round. Move that unit's allied neighbors to random other lanes.  
*Note:* Signature card of 黄月英 Huang Yueying: attach `assets/art/heroes_reserve/huangyueying.png` as a reference so the face matches. Match the Wooden Beast token (Batch 6) so the war-beasts look the same.

```text
Huang Yueying in practical crimson robes directing two carved wooden war-beasts that breathe fire and smoke. The enemy war elephant blocking them is frozen in place, stunned, while the beasts beside it flee in panic in different directions through the jungle. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 136. 飞军天降 / Flying Army Descends — `assets/art/cards/spring_the_trap.png`

*Card:* Summon two Wudang Flying Army into any lane.  
*Note:* Match the Wudang Flying Army card art (centaur_hunter).

```text
Two light-armoured Wudang mountain warriors in crimson headwraps and hemp tunics leaping down a misty cliff path and bursting out of the forest onto a startled enemy flank, more of their comrades and war drums on the slope behind them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 137. 桃园结义 / Peach Garden Oath — `assets/art/cards/time_of_triumph.png`

*Card:* Permanently give allied heroes +4 attack, +4 armor, +4 health, +4 cleave, +4 retaliate and +4 siege.  
*Note:* Attach Liu Bei (liubei.png), Guan Yu (keefe) and Zhang Fei (axe).

```text
Liu Bei, Guan Yu and Zhang Fei kneeling side by side before an incense altar beneath blossoming peach trees, wine cups raised together. A column of warm golden light rises from the altar and wraps all three brothers, as pink petals swirl around them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Shu (red) - Creeps (11)**

### 138. 东州兵 / Dongzhou Exiles — `assets/art/cards/mercenary_exiles.png`

*Card:* Empty the Purse: spend all your gold, then permanently give Dongzhou Exiles +X attack and +X health, where X is half the gold spent. Active ability; cooldown 2.  

```text
A hard-faced refugee soldier of the Dongzhou exiles in mismatched armour, weighing a heavy jingling purse of coins in one hand, a notched sword resting on his shoulder, his muscles visibly swelling as he pours the coins out. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 139. 绊马索兵 / Snare-Rope Troops — `assets/art/cards/hellbear_crippler.png`

*Card:* When Snare-Rope Troops deal battle damage to a unit, permanently give that unit -1 attack.  

```text
A crouching Shu soldier yanking a taut rope across a forest trail with both hands, a horse stumbling and its rider pitching forward in the background. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 140. 蒲元刀匠 / Pu Yuan's Smiths — `assets/art/cards/smeevil_armsmaster.png`

*Card:* Play effect: permanently give a random allied hero +2 attack.  

```text
A sweat-streaked Shu swordsmith in a leather apron holding up a freshly quenched blade that glows orange, sparks and steam rising from the forge behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 141. 涿郡义兵 / Zhuo Volunteers — `assets/art/cards/rebel_instigator.png`

*Card:* After the combat phase, if Zhuo Volunteers dealt battle damage to a creep this round, summon a Zhuo Volunteers.  

```text
A rough farmer-turned-soldier with a sharpened hoe-spear and a red headband, rallying fellow villagers behind him and waving them forward. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 142. 牙门旗手 / Yamen Standard Bearer — `assets/art/cards/legion_standard_bearer.png`

*Card:* Yamen Standard Bearer's allied neighbors have +4 attack.  

```text
A stout, unarmed soldier planting a huge plain crimson command banner with both hands, the blank cloth snapping in the wind above the battle line. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 143. 虎步军 / Tiger-Step Elite — `assets/art/cards/stonehall_elite.png`

*Card:* Permanently give Tiger-Step Elite +2 attack and +2 health after a unit blocking it dies.  

```text
An elite Shu infantryman in tiger-striped lamellar armour and a tiger-mask helmet, stepping over a fallen foe with his halberd raised. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 144. 连弩手 / Repeating Crossbowmen — `assets/art/cards/ogre_corpse_tosser.png`

*Card:* Deal 2 piercing damage to the enemy tower after an allied Foot Soldier dies.  

```text
A sturdy Shu crossbowman behind a wooden mantlet, loading a repeating crossbow with a box magazine and aiming it upward toward distant fortress walls. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 145. 泸水残兵 / Lu River Veterans — `assets/art/cards/cursed_satyr.png`

*Card:* Summon a Ghost Soldier for your opponent after the combat phase.  
*Note:* Its ghosts should match the Ghost Soldier token (Batch 6).

```text
A grim Shu veteran wading out of a misty river at night, crimson armour streaming with water, as pale ghostly soldiers rise from the current behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 146. 西凉铁骑 / Xiliang Iron Cavalry — `assets/art/cards/red_mist_pillager.png`

*Card:* After the combat phase, if Xiliang Iron Cavalry dealt battle damage to a tower this round, summon a Xiliang Iron Cavalry.  

```text
A northwestern horseman in fur-trimmed iron armour galloping hard past a smoking fortress wall, a dust plume of more riders behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 147. 木牛流马 / Wooden Ox — `assets/art/cards/keenfolk_golem.png`

*Card:* Play effect: discard your hand.  
*Note:* A machine, so it stands in for the main figure; its head takes the face's place in the board crop.

```text
A towering wooden ox automaton of interlocking timbers, gears and bronze fittings striding forward along a mountain plank road. Treat the ox as the single main figure, its carved head in the upper-middle. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 148. 板楯蛮 / Banshun Shieldmen — `assets/art/cards/marrowfell_brawler.png`

*Card:* Creep: 6 attack, 0 armor, 16 health.  

```text
A massive tribal warrior from the Ba hills behind a tall painted wooden board-shield, bare-armed and tattooed, with a heavy club braced to strike. Dignified, not a caricature. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Shu (red) - Improvements (7)**

### 149. 滚木礌石 / Logs and Boulders — `assets/art/cards/burning_oil.png`

*Card:* Your tower has +2 retaliate.  

```text
Defenders atop a crimson-bannered gate tower heaving huge logs and boulders over the parapet onto the ladders and attackers below. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 150. 蜀道 / Road to Shu — `assets/art/cards/path_of_the_bold.png`

*Card:* After you play a red card, permanently give a random ally +1 attack.  

```text
The narrow wooden plank road to Shu, bolted to a sheer cliff face above a misty gorge, with a column of red-bannered soldiers marching along it at sunset. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 151. 成都武库 / Chengdu Arsenal — `assets/art/cards/temple_of_war.png`

*Card:* All equipped heroes have +2 attack and +1 armor.  

```text
The interior of a great timber armoury hall in Chengdu with racks of glaives, spears and lamellar armour gleaming under lantern light, crimson banners hanging from the beams. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 152. 阵前斗将 / Clash of Champions — `assets/art/cards/grand_melee.png`

*Card:* If there is an allied red hero in this lane, all heroes have +2 cleave.  

```text
Two mounted champions clashing in the open ground between two drawn-up armies, dust swirling, crimson banners on one side and dark banners on the other. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 153. 将计就计 / Turn the Tables — `assets/art/cards/nether_ward.png`

*Card:* After your opponent plays a spell, deal 3 damage to the enemy tower.  
*Note:* Signature card of 诸葛亮 Zhuge Liang: attach `assets/art/heroes_reserve/zhugeliang.png` as a reference so the face matches. Zhuge Liang's ability card.

```text
Zhuge Liang seated calmly with his feather fan on a river bluff while, across the water, the enemy's own fire boats drift back on the wind and set their fleet alight. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 154. 孙夫人城 / Lady Sun's Fort — `assets/art/cards/steel_reinforcement.png`

*Card:* Your tower has +1 armor.  
*Note:* Signature card of 孙尚香 Sun Shangxiang: attach `assets/art/heroes_reserve/sunshangxiang.png` as a reference so the face matches. Regenerate that portrait first (see *Hero portraits to regenerate*), because 孙尚香 moved from Wu to Shu.

```text
Sun Shangxiang in crimson armour with a bow in hand on the battlements of a small riverside fort, armed handmaidens beside her and red banners over the gate. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 155. 白帝城 / Baidi Citadel — `assets/art/cards/the_omexe_arena.png`

*Card:* Draw a card after a hero dies.  

```text
Baidi Citadel, a walled citadel on a cliff above the Yangtze gorges at dusk, lanterns glowing in its halls and mist rising off the river below. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Batch 2 - Wei (blue) (42)

**Wei (blue) - Spells (28)**

### 156. 虎豹骑冲阵 / Tiger-Leopard Charge — `assets/art/cards/strafing_run.png`

*Card:* Deal 2 damage to each enemy creep.  

```text
Cao Cao's Tiger and Leopard Cavalry, heavily armoured horsemen with tiger-striped barding and steel-blue pennants, sweeping in one wide line across a dusty plain through a rabble of panicked enemy foot soldiers, every light infantryman in their path knocked flying. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 157. 割发代首 / Hair for a Head — `assets/art/cards/diabolic_revelation.png`

*Card:* Draw 2 cards. Deal 2 damage to allies in all lanes.  
*Note:* Attach the Cao Cao card art (jmuy).

```text
Cao Cao, a stern Wei lord in dark armour, slicing off his own topknot with a sword before kneeling ranks of soldiers in a trampled wheat field under a grey sky. The soldiers in every row flinch as if each one felt the cut himself. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 158. 激将法 / Provocation — `assets/art/cards/ventriloquy.png`

*Card:* Choose a unit. It taunts.  

```text
A Wei herald on horseback below a city wall, shouting insults up at an enraged enemy general who leans over the battlements gripping his weapon, about to storm out of the gate. Every eye on the field is drawn to the furious general. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 159. 割须弃袍 / Cut Beard, Shed Robe — `assets/art/cards/cunning_plan.png`

*Card:* Swap a unit with one of its allied neighbors. Draw a card.  
*Note:* Attach the Cao Cao card art (jmuy).

```text
Cao Cao, hunted, slashing off his beard with a dagger and flinging away his red robe as he gallops among his own riders through a dusty pass. The rider beside him has caught the discarded robe and pulled it on, swapping places with him to draw the pursuit. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 160. 梦中杀人 / Killing in My Dreams — `assets/art/cards/whispers_of_madness.png`

*Card:* Stun an enemy this round and stun allied heroes in all lanes this round.  
*Note:* Attach the Cao Cao card art (jmuy).

```text
Cao Cao half-risen from a dark bed with a sword in hand, nightmare shadows coiling around him in cold blue moonlight. An attendant in the doorway is frozen in mid-step, and the lord himself is frozen in mid-motion too, as if time has stopped for both of them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 161. 煮酒论英雄 / Heroes Over Plum Wine — `assets/art/cards/rolling_storm.png`

*Card:* Deal 2 damage to all towers in all lanes.  
*Note:* Attach Cao Cao (jmuy) and the Liu Bei portrait (liubei.png).

```text
Cao Cao and Liu Bei seated at a pavilion table with a bronze wine kettle and a dish of green plums, while a jagged bolt of lightning splits the stormy sky and strikes the watchtowers of distant city walls. Liu Bei has dropped his chopsticks in alarm. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 162. 拔矢啖睛 / Eating His Own Eye — `assets/art/cards/frostbite.png`

*Card:* Deal 2 damage to a unit and disarm it this round.  
*Note:* Signature card of 夏侯惇 Xiahou Dun: attach `assets/art/heroes_reserve/xiahoudun.png` as a reference so the face matches.

```text
Xiahou Dun on horseback wrenching an arrow out of his wounded eye, his hand and the shaft hiding the eye with no gore, roaring in defiance. The enemy archer before him has dropped his bow in horror and stands empty-handed. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 163. 千金悬赏 / Thousand-Gold Bounty — `assets/art/cards/wrath_of_gold.png`

*Card:* Spend all your gold. Repeat once for each gold spent: deal 4 damage to a random ally or enemy.  

```text
A chest of gold coins (blank, no markings) spilling across a war table in a torch-lit Wei hall, as shadowy hired blades leap out of the dark in every direction, their swords flashing at friend and foe alike. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 164. 徐晃援樊 / Xu Huang's Relief — `assets/art/cards/better_late_than_never.png`

*Card:* Summon a Foot Soldier into any lane.  
*Note:* Match the Foot Soldier card art (melee_creep).

```text
Xu Huang, a Wei general with a great axe, leading a small relief party through flooded fields toward a besieged city wall at dusk, one plain foot soldier with a spear and round shield striding out in front. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 165. 缓兵之计 / Stalling Tactics — `assets/art/cards/buying_time.png`

*Card:* Give two random cards in your opponent's hand +2 lock.  

```text
A smiling Wei envoy bowing low and presenting a gift chest to an impatient enemy general, while thin chains of pale blue light quietly wind around the general's sword hilt. Behind the envoy, workers hurriedly raise a city wall. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 166. 调虎离山 / Lure the Tiger — `assets/art/cards/compel.png`

*Card:* Choose a unit. Choose a combat target for it. Draw a card.  

```text
A great tiger lured down from its misty mountain lair toward a bait goat tethered in a clearing, its eyes fixed on the prey, while Wei archers hide in the pines on both sides, waiting to choose their moment. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 167. 宁我负人 / Let Me Wrong the World — `assets/art/cards/at_any_cost.png`

*Card:* Deal 6 damage to every unit.  
*Note:* Attach the Cao Cao card art (jmuy). Keep it bloodless.

```text
Cao Cao, cold-eyed, standing with a drawn sword in a moonlit farmhouse courtyard, overturned lanterns and fallen silhouettes all around him, as a cold blue shockwave rolls outward over everyone in the scene. No gore. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 168. 屯兵淮南 / Garrison the Huai — `assets/art/cards/sow_venom.png`

*Card:* Summon two Farm Soldiers.  
*Note:* Signature card of 邓艾 Deng Ai: attach `assets/art/heroes_reserve/dengai.png` as a reference so the face matches. Match the Farm Soldier token (Batch 6).

```text
Deng Ai in practical dark iron armour on a dyke between flooded Huai river fields, pointing with his spear as two soldier-farmers in straw rain capes shoulder sharpened hoe-spears and march out to the front, more columns following under steel-blue banners. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 169. 分兵疾进 / Split and Advance — `assets/art/cards/divided_we_stand.png`

*Card:* Summon a Xiahou Yuan.  
*Note:* Signature card of 夏侯渊 Xiahou Yuan: attach `assets/art/heroes_reserve/xiahouyuan.png` as a reference so the face matches.

```text
Xiahou Yuan galloping at the head of his Wei light cavalry across a frosty plain, so fast that a second, identical rider splits away from him on a parallel line, the columns fanning out in different directions. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 170. 仿造木牛 / Copy the Wooden Ox — `assets/art/cards/and_one_for_me.png`

*Card:* Choose a hero. Put a base copy of a random item equipped by that hero into your hand.  

```text
Wei craftsmen in a lantern-lit workshop measuring a captured wooden ox automaton with cords and rulers, while an identical copy takes shape beside it in fresh pale timber. The plans on the bench are drawings only, with no writing. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 171. 捉放曹 / Catch and Release — `assets/art/cards/astral_imprisonment.png`

*Card:* Stun a unit this round. Give it damage immunity this round.  
*Note:* Signature card of 陈宫 Chen Gong: attach `assets/art/heroes_reserve/chengong.png` as a reference so the face matches. Regenerate that portrait first (see *Hero portraits to regenerate*), because 陈宫 moved from Qun to Wei. Also attach the Cao Cao card art (jmuy).

```text
Chen Gong in dark indigo magistrate's robes unlocking a wooden cangue from the neck of the captive Cao Cao in a moonlit county jail. The guards stand frozen in surprise, and a faint protective blue glow wraps Cao Cao as he goes free. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 172. 抹书间韩 / The Smudged Letter — `assets/art/cards/self_sabotage.png`

*Card:* Modify two random cards in your opponent's hand with "Deal 6 damage to a random allied tower in any lane."  

```text
A letter covered in heavy ink smudges and blots (no legible characters) lying on a war table between two glaring western warlords, one jabbing at the blots in suspicion, while a Wei agent slips away into the shadows behind them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 173. 驱虎吞狼 / Tiger Against Wolf — `assets/art/cards/prey_on_the_weak.png`

*Card:* Summon a Hungry Tiger for each damaged unit.  
*Note:* Signature card of 荀彧 Xun Yu: attach `assets/art/heroes_reserve/xunyu.png` as a reference so the face matches. Match the Hungry Tiger token (Batch 6).

```text
Xun Yu, elegant in indigo court robes, calmly unrolling a blank scroll on a ridge while lean tigers stream down the slope toward the wounded soldiers in the misty valley below, one tiger for each wounded man. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 174. 声东击西 / Feint East, Strike West — `assets/art/cards/arcane_assault.png`

*Card:* Deal 2 damage to the enemy tower. Draw a card. Get initiative.  

```text
Wei campfires left blazing on one riverbank as a decoy while the real Wei army slips across a ford in the dark and strikes the walls of an enemy fort, a burst of fire flaring on the fort gate. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 175. 虚张声势 / Decoy Army — `assets/art/cards/fog_of_war.png`

*Card:* Each enemy has a 50% chance of being disarmed this round.  

```text
Straw dummies in Wei armour and dozens of plain, blank banners lining a misty hillside, while a wary enemy army in the valley below hesitates and lowers its weapons in confusion. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 176. 洛神赋 / Ode to the Luo Goddess — `assets/art/cards/eclipse.png`

*Card:* Repeat once for each charge: deal 3 piercing damage to a random enemy.  
*Note:* Signature card of 甄姬 Zhen Ji: attach `assets/art/heroes_reserve/zhenji.png` as a reference so the face matches.

```text
Zhen Ji drifting over moonlit river water in flowing indigo silks, her sleeves trailing, as crescent blades of pale light fall one by one from an eclipsed moon onto an enemy camp on the far bank. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 177. 掷短戟 / Hail of Short Halberds — `assets/art/cards/mystic_flare.png`

*Card:* Deal 12 damage divided evenly among a unit and its allied neighbors.  
*Note:* Signature card of 典韦 Dian Wei: attach `assets/art/heroes_reserve/dianwei.png` as a reference so the face matches.

```text
Dian Wei, massive and bare-armed, hurling a fan of short halberds from both hands into a cluster of three charging enemy soldiers, the halberds spreading evenly across all three. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 178. 千里请战 / Thousand-Li Petition — `assets/art/cards/lost_in_time.png`

*Card:* Give three random cards in your opponent's hand +3 lock.  

```text
A Wei courier galloping along an endless frosty road with a sealed petition tube on his back, while far ahead an enemy army waits idle behind its palisade, chains of pale blue frost wrapped around its banners and weapons. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 179. 三日五百里 / Three-Day Forced March — `assets/art/cards/call_the_reserves.png`

*Card:* Summon two Foot Soldiers into any lane.  
*Note:* Match the Foot Soldier card art (melee_creep).

```text
A column of dust-covered Wei foot soldiers jogging at speed along a mountain road at dawn, banners streaming, two soldiers with spears and round shields at the front, and a besieged fort waiting far ahead. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 180. 二虎竞食 / Two Tigers, One Prey — `assets/art/cards/friendly_fire.png`

*Card:* Choose two enemies. They battle each other.  

```text
Two snarling tigers fighting over a single carcass on a misty ridge, claws locked, while a calm Wei strategist watches from a pavilion far above them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 181. 十面埋伏 / Ambush on Ten Sides — `assets/art/cards/remote_detonation.png`

*Card:* Deal 5 damage to each enemy across from an empty combat position.  

```text
Wei soldiers rising out of tall frosted reeds on every side of a startled enemy column on what looked like an empty plain at dawn, spears levelled from all directions. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 182. 辽来止啼 / Liao Is Coming — `assets/art/cards/echo_slam.png`

*Card:* Deal damage to each enemy equal to the number of enemies.  
*Note:* Signature card of 张辽 Zhang Liao: attach `assets/art/heroes_reserve/zhangliao.png` as a reference so the face matches.

```text
Zhang Liao on a rearing warhorse at the head of a small band of riders, his charging silhouette looming out of a storm over a crowded Wu army camp. Soldiers scatter and fall in a widening shockwave of panic, and the bigger the crowd, the bigger the wave. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 183. 火烧乌巢 / Burning of Wuchao — `assets/art/cards/bolt_of_damocles.png`

*Card:* Deal 20 damage to the enemy tower.  

```text
Wei raiders silhouetted against an enormous night blaze consuming a vast walled granary, storehouse roofs collapsing and embers and smoke rising into a cold indigo sky. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Wei (blue) - Creeps (4)**

### 184. 敢死士 / Dare-to-Die Men — `assets/art/cards/relentless_zombie.png`

*Card:* Play effect: give Dare-to-Die Men a death shield.  

```text
A scarred Wei volunteer in battered lamellar with a broken spear, staggering back to his feet with grim resolve amid drifting smoke, a faint shell of blue light around him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 185. 典农校尉 / Agrarian Colonel — `assets/art/cards/satyr_magician.png`

*Card:* Open the Granary: fully restore your tower's mana. Active ability; cooldown 1.  

```text
A Wei farm-colony official in practical robes and light armour throwing open granary doors as sacks of grain are loaded onto army carts behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 186. 管辂 / Guan Lu the Diviner — `assets/art/cards/troll_soothsayer.png`

*Card:* Draw an extra card each round.  

```text
Guan Lu, an eccentric Wei diviner in rumpled robes, casting yarrow stalks before a bronze divination board, star patterns glowing faintly in the mist around him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 187. 曹植 / Cao Zhi — `assets/art/cards/incarnation_of_selemene.png`

*Card:* Fully restore your tower's mana after you play any card.  

```text
The young poet-prince Cao Zhi in indigo court robes, brush raised over a long blank scroll on a moonlit terrace above a misty river. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Wei (blue) - Improvements (10)**

### 188. 驿站 / Post Station — `assets/art/cards/messenger_rookery.png`

*Card:* Relay Orders: choose an ally, then choose a combat target for it. Active ability; cooldown 1.  

```text
A Wei relay rider galloping out of a small walled post station at dawn, a fresh horse being saddled at the gate and a sealed order tube on his back. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 189. 斥候营 / Scout Camp — `assets/art/cards/watchtower.png`

*Card:* Whenever an enemy improvement enters this lane, draw a card.  

```text
Wei scouts crouched on a wooden lookout platform in the pines, one of them sketching the enemy siege works being raised in the valley below. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 190. 坚壁清野 / Walls and Bare Fields — `assets/art/cards/fractured_timeline.png`

*Card:* Before the action phase, give a random card in your opponent's hand +1 lock.  

```text
A strong Wei city wall at dusk, with harvested, empty fields and stripped orchards stretching to the horizon and a hungry enemy army camped in the distance. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 191. 太学 / Imperial Academy — `assets/art/cards/path_of_the_wise.png`

*Card:* After you play a blue card, deal 1 piercing damage to a random enemy.  

```text
Rows of scholars studying bamboo scrolls in a grand Wei academy hall, cold blue lamplight on lacquered pillars. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 192. 十胜十败 / Ten Wins, Ten Losses — `assets/art/cards/ignite.png`

*Card:* Deal 1 piercing damage to each enemy before the action phase.  
*Note:* Signature card of 郭嘉 Guo Jia: attach `assets/art/heroes_reserve/guojia.png` as a reference so the face matches.

```text
Guo Jia at a lamp-lit table laying ten black and ten white stones across a painted map, ghostly enemy banners crumbling at the map's edge. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 193. 月旦评 / Monthly Appraisals — `assets/art/cards/howling_mind.png`

*Card:* You and your opponent draw an extra card each round.  

```text
A crowd of scholars and officials gathered at a Han pavilion as a critic delivers his judgements, blank scrolls passed from hand to hand under winter morning light. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 194. 铜雀台 / Bronze Sparrow Terrace — `assets/art/cards/aghanims_sanctum.png`

*Card:* Court Audience: fully restore your tower's mana. Active ability; cooldown 1.  

```text
The towering multi-storey Bronze Sparrow Terrace at Ye under a cold moon, a great bronze sparrow on its roof and lanterns glowing on every level. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 195. 虎卫营 / Tiger Guard Camp — `assets/art/cards/barracks.png`

*Card:* Summon a Foot Soldier into this lane each deployment phase.  
*Note:* Signature card of 许褚 Xu Chu: attach `assets/art/heroes_reserve/xuchu.png` as a reference so the face matches.

```text
A fortified Wei camp at dusk with watchtowers and tiger-striped banners, its gate open as Xu Chu waves a column of guards out to the field. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 196. 强弩营 / Crossbow Battery — `assets/art/cards/conflagration.png`

*Card:* Deal 2 damage to each enemy before the action phase.  

```text
Ranks of Wei crossbowmen in dark iron lamellar loosing a synchronised volley from behind a fortified rampart, bolts filling a frost-grey sky. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 197. 陷马坑 / Horse Pitfalls — `assets/art/cards/glyph_of_confusion.png`

*Card:* Whenever any unit enters this lane, stun it this round.  

```text
A charging warhorse and rider plunging into a hidden reed-covered pit lined with stakes on a misty plain, Wei pikemen waiting beyond. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Batch 3 - Wu (green) (42)

**Wu (green) - Spells (22)**

### 198. 金蝉脱壳 / Cicada Sheds Its Shell — `assets/art/cards/juke.png`

*Card:* Swap an ally with one of its allied neighbors.  

```text
In a moonlit reed marsh, an empty suit of armour propped on a pole like a cicada's cast-off shell, while its owner slips away into the reeds and a comrade quietly steps into his place in the line. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 199. 奋身护主 / Shield the Lord — `assets/art/cards/aphotic_shield.png`

*Card:* Purge your opponent's effects from a unit. Give it +2 armor and +2 retaliate this round.  
*Note:* Signature card of 周泰 Zhou Tai: attach `assets/art/heroes_reserve/zhoutai.png` as a reference so the face matches. Also attach the Sun Quan card art (farvhan).

```text
Zhou Tai, scarred and bleeding, spreading his arms and round shield in front of the young Wu lord Sun Quan as torches and spears close in at night. A jade glow surrounds them both, and the enemy's arrows snap and fall away from it. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 200. 列盾相护 / Shields Together — `assets/art/cards/defend_the_weak.png`

*Card:* Permanently give a unit "This unit's allied neighbors have +2 armor."  

```text
A Wu officer planting a tall lacquered teal shield at the centre of a locked shield wall, a jade glow spreading sideways from his shield to cover the comrades on each side of him. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 201. 擂鼓 / Pounding Drums — `assets/art/cards/bellow.png`

*Card:* Move a creep to a random other lane.  

```text
A bare-armed drummer pounding a huge war drum on a ship's prow, shockwaves of sound rippling outward across the water and sweeping a startled enemy soldier away into the mist. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 202. 蒙冲掩护 / Mengchong Cover — `assets/art/cards/iron_branch_protection.png`

*Card:* Give a unit in any lane +3 armor until the end of its next combat phase.  

```text
A low, hide-armoured mengchong warship sliding between a stranded soldier on a sandbar and a hail of arrows, which bounce harmlessly off its leather roof. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 203. 犒赏三军 / Reward the Army — `assets/art/cards/rumusque_blessing.png`

*Card:* Choose a lane. Permanently give allies in that lane +3 health.  

```text
Rows of Wu soldiers raising wine bowls at long tables piled with fish and rice on a lantern-lit riverside pier, green war-junk sails behind them and a warm, healthy glow on every face. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 204. 诈降火船 / Fire Ship Feint — `assets/art/cards/viper_strike.png`

*Card:* Give a unit "Before the action phase, deal 2 piercing damage to this unit" until it dies.  
*Note:* Signature card of 黄盖 Huang Gai: attach `assets/art/heroes_reserve/huanggai.png` as a reference so the face matches.

```text
Huang Gai, grizzled and fierce, on the prow of a small boat packed with oil-soaked reeds, a plain white surrender flag in his hand, as the boats behind him burst into flame and drift toward a dark enemy fleet. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 205. 激昂 / Rousing Fervor — `assets/art/cards/empower.png`

*Card:* Permanently give a unit +3 attack and +3 cleave.  
*Note:* Signature card of 孙策 Sun Ce: attach `assets/art/heroes_reserve/sunce.png` as a reference so the face matches.

```text
Sun Ce with his spear raised on a riverbank, clapping a young soldier on the shoulder as the soldier's blade flares with golden light and sweeps a wide arc, while the ranks behind them roar. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 206. 神亭酣斗 / Duel at Shenting — `assets/art/cards/ion_shell.png`

*Card:* Permanently give a unit +3 retaliate.  
*Note:* Signature card of 太史慈 Taishi Ci: attach `assets/art/heroes_reserve/taishici.png` as a reference so the face matches. Also attach the Sun Ce portrait (sunce.png).

```text
Taishi Ci and the young Wu lord Sun Ce grappling on horseback on a misty ridge, one gripping the other's spear and the other holding a snatched helmet, both trading blow for blow. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 207. 濡须筑坞 / Fortify Ruxu — `assets/art/cards/defensive_bloom.png`

*Card:* Summon two Spiked Barricades.  
*Note:* Match the Spiked Barricade token (Batch 6).

```text
Wu soldiers hammering sharpened timber stakes into a riverbank to raise two spiked barricades in front of a new fortified dock, war-junks moored behind the fresh palisade. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 208. 琴瑟和鸣 / Zither in Harmony — `assets/art/cards/allseeing_ones_favor.png`

*Card:* Permanently give a green hero "Allies have +2 regeneration."  
*Note:* Signature card of 小乔 Xiao Qiao: attach `assets/art/heroes_reserve/xiaoqiao.png` as a reference so the face matches. Also attach the Zhou Yu card art (drow).

```text
Xiao Qiao playing a guqin in a riverside pavilion while Zhou Yu in green listens, soft ribbons of jade light drifting from the strings over resting Wu soldiers whose wounds are closing. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 209. 筑石头城 / Raise Stone City — `assets/art/cards/restoration_effort.png`

*Card:* Heal your tower 8.  

```text
Labourers hauling and stacking great grey stones to raise and repair a fortress wall on a cliff above the river, scaffolding and pulleys silhouetted in mist, the fresh stones glowing faintly as the wall heals. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 210. 养精蓄锐 / Rest and Recover — `assets/art/cards/soul_of_spring.png`

*Card:* Permanently give a hero "After you play a green card, give this hero and its allied neighbors +4 regeneration this round."  

```text
A Wu general and his officers resting beside a spring under willow trees, armour loosened, fresh green light filtering through the branches and pooling around them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 211. 临江祓禊 / River Purification — `assets/art/cards/cleansing_rite.png`

*Card:* Purge your opponent's effects from a hero.  

```text
A Wu general kneeling at the river's edge as a robed ritualist pours water from a bronze vessel over his hands, dark smoky curses washing off him into the current, with mist and willow catkins drifting. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 212. 卑辞骄敌 / Lull with Flattery — `assets/art/cards/caught_unprepared.png`

*Card:* Stun a hero until they equip an item.  
*Note:* Attach the Guan Yu card art (keefe).

```text
Guan Yu, the proud long-bearded general in a green robe, lounging in his tent and smiling over an unrolled flattering letter (no legible text), his crescent glaive neglected on the weapon rack behind him. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 213. 偷梁换柱 / Swap the Beams — `assets/art/cards/steal_strength.png`

*Card:* Give a unit -4 attack this round and give another unit +4 attack this round.  

```text
A sly Wu officer slipping a heavy halberd from a sleeping enemy's weapon rack and passing it to a waiting comrade in a shadowy camp, the halberd glowing as it changes hands. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 214. 江南瘴疠 / Southern Miasma — `assets/art/cards/corrosive_mist.png`

*Card:* Condemn all equipped items.  

```text
Thick yellow-green fog rolling over a riverside camp, with rusting spears, rotting lamellar and corroded helmets heaped on the muddy bank. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 215. 长江天堑 / The Yangtze Barrier — `assets/art/cards/divine_intervention.png`

*Card:* Give allies damage immunity this round.  

```text
The vast misty Yangtze separating a calm Wu shore from a distant northern army, whose arrows fall short and drop harmlessly into the churning water. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 216. 疑城退敌 / Phantom Ramparts — `assets/art/cards/intimidation.png`

*Card:* Move a unit to a random other lane.  

```text
At dawn, endless painted cloth walls and towers line the misty Yangtze shore while an awed enemy fleet turns about and sails away into the distance. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 217. 水土不服 / Ill-Suited to the South — `assets/art/cards/curse_of_atrophy.png`

*Card:* Permanently give enemy heroes -2 attack.  

```text
Feverish northern generals in heavy iron armour sagging over the rail of a rocking warship, pale and seasick, their weapons drooping, under a damp grey southern sky. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 218. 指囷相赠 / Granary Gift — `assets/art/cards/hand_of_god.png`

*Card:* Fully heal each ally. Give allies damage immunity this round.  
*Note:* Signature card of 鲁肃 Lu Su: attach `assets/art/heroes_reserve/lusu.png` as a reference so the face matches.

```text
Lu Su in green scholar robes pointing to an open granary as grain pours out to a line of weary soldiers, golden light washing over them and healing their wounds. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 219. 天命所归 / Mandate of Heaven — `assets/art/cards/divine_purpose.png`

*Card:* Permanently give a unit damage immunity.  

```text
A lone Wu commander standing unharmed in a beam of golden light from parting clouds while arrows fall away around him on a river bluff. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Wu (green) - Creeps (12)**

### 220. 丹阳兵 / Danyang Diehards — `assets/art/cards/vhoul_martyr.png`

*Card:* Death effect: permanently give allies +1 attack and +1 health.  

```text
A grim young Danyang soldier with a short blade charging forward, headband streaming, as his comrades rally behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 221. 祖茂 / Zu Mao — `assets/art/cards/rebel_decoy.png`

*Card:* Swapped Headscarf: swap Zu Mao with another ally. Active ability; cooldown 1.  
*Note:* Zu Mao wore Sun Jian's red headscarf to draw off the pursuit.

```text
Zu Mao, a loyal Wu officer, tying a red headscarf onto his own head in a moonlit forest while pursuing torches close in behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 222. 吴越铸师 / Wu-Yue Armorsmith — `assets/art/cards/smeevil_blacksmith.png`

*Card:* Play effect: permanently give a random allied hero +1 armor.  

```text
A soot-streaked smith in a leather apron hammering a glowing lamellar plate at a riverside forge, sparks flying in teal shadow. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 223. 吴钩剑客 / Wu Hook Duelist — `assets/art/cards/satyr_duelist.png`

*Card:* Permanently give Wu Hook Duelist +2 attack after the combat phase.  

```text
A lean swordsman in a teal sash crouched in a duelling stance with a curved hook-sword, rain dripping from a reed-thatched roof behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 224. 山越蛮兵 / Shanyue Berserkers — `assets/art/cards/rampaging_hellbear.png`

*Card:* Permanently give Shanyue Berserkers +4 attack after the combat phase.  

```text
A muscular Shanyue hill warrior with bone ornaments and a heavy axe, roaring as he charges down a misty mountain slope. Dignified, not a caricature. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 225. 陆家部曲 / Lu Clan Retainers — `assets/art/cards/roseleaf_druid.png`

*Card:* Your tower has +1 mana.  
*Note:* Signature card of 陆逊 Lu Xun: attach `assets/art/heroes_reserve/luxun.png` as a reference so the face matches.

```text
An armed Lu clan retainer in teal livery standing at a riverside manor gate, unloading grain and arrows, with the young Lu Xun watching from the steps behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 226. 越巫 / Yue Shaman — `assets/art/cards/selfish_cleric.png`

*Card:* Fully heal Yue Shaman after the combat phase.  

```text
A hooded southern shaman with a bronze bell and herb pouch chanting over his own glowing wound in a fern-filled forest clearing, the wound closing in jade light. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 227. 漕船队 / Grain Barge Fleet — `assets/art/cards/revtel_convoy.png`

*Card:* Grain Barge Fleet has +X attack, where X is half your gold.  
*Note:* A vehicle, so it uses the Tower Ship framing line.

```text
A heavily laden Wu river barge stacked with grain sacks and bronze-bound chests pushing through morning mist, armed boatmen on deck. Vertical portrait composition. The ship is the single main subject, shown bow-on at three-quarters. Its upper deck and banner sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (water and mist). The hull, oars and mast must not touch or cross the frame edges. The background is soft and less detailed than the ship. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 228. 无难军 / Wunan Guard — `assets/art/cards/champion_of_the_ancient.png`

*Card:* Play effect: permanently give Wunan Guard +1 attack, +1 health and +1 cleave for each enemy.  

```text
A towering Wu guardsman in ornate teal lamellar planting a long glaive before a palace gate, ready to cut down many foes at once. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 229. 杏林医仙 / Apricot Grove Healer — `assets/art/cards/roseleaf_rejuvenator.png`

*Card:* Play effect: heal your tower 7.  

```text
A white-bearded physician in green robes beneath a blossoming apricot grove, holding a medicine gourd as petals drift toward a mended city wall behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 230. 诸葛瑾 / Zhuge Jin — `assets/art/cards/emissary_of_the_quorum.png`

*Card:* Envoy of Alliance: permanently give allies +2 attack and +2 health. Active ability; cooldown 1.  

```text
Zhuge Jin, a calm, long-faced elder envoy in green court robes, holding out a sealed letter of alliance in a riverside pavilion, banners stirring behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 231. 飞云大船 / Feiyun Flagship — `assets/art/cards/thunderhide_alpha.png`

*Card:* Creep: 25 attack, 0 armor, 25 health.  
*Note:* A vehicle, so it uses the Tower Ship framing line. Match the Tower Ship card art (thunderhide_pack) but larger.

```text
A colossal multi-deck Wu flagship with layered pavilions and vast batwing sails looming bow-on out of the river mist, dwarfing the small boats around it. Its banners are plain and unmarked. Vertical portrait composition. The ship is the single main subject, shown bow-on at three-quarters. Its upper deck and banner sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (water and mist). The hull, oars and mast must not touch or cross the frame edges. The background is soft and less detailed than the ship. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Wu (green) - Improvements (8)**

### 232. 江防烽燧 / River Beacons — `assets/art/cards/unearthed_secrets.png`

*Card:* Draw a card after the combat phase if your tower was dealt damage this round.  

```text
A chain of stone beacon towers along a misty riverbank flaring to life one after another, smoke columns rising into the dusk. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 233. 鱼米之乡 / Land of Fish and Rice — `assets/art/cards/path_of_the_dreamer.png`

*Card:* After you play a green card, give your tower +3 regeneration until the end of the round.  

```text
Terraced rice paddies and fish ponds below a riverside fort, farmers carrying baskets of rice and fish up to the gate in morning light. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 234. 水师操练 / Fleet Drills — `assets/art/cards/mist_of_avernus.png`

*Card:* Permanently give allies +1 attack before the action phase.  

```text
Rows of war-junks manoeuvring in formation on a misty river while marines on deck practise spear drills to a commander's flag signals. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 235. 以逸待劳 / Wait Out the Weary — `assets/art/cards/homefield_advantage.png`

*Card:* Before the action phase, disarm a random enemy this round.  

```text
Rested Wu soldiers sitting calmly behind a palisade sharpening blades, while beyond it a column of exhausted enemy soldiers slumps in the summer heat. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 236. 定都建业 / Capital at Jianye — `assets/art/cards/selemenes_favor.png`

*Card:* Your tower has +2 mana.  

```text
Jianye, a walled riverside capital with tiered palace halls and teal-tiled roofs above the Yangtze, war-junks moored along its quays in evening mist. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 237. 伤兵营 / Field Infirmary — `assets/art/cards/altar_of_the_mad_moon.png`

*Card:* Allied Foot Soldiers have +2 regeneration.  

```text
Inside a lantern-lit army tent, medics bandage ordinary foot soldiers lying on straw mats while herbal steam rises from clay pots. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 238. 吉人天相 / Heaven Protects — `assets/art/cards/cheating_death.png`

*Card:* Heaven's Aid: give a unit a death shield this round. Only usable if there is an allied green hero in this lane. Active ability; cooldown 1.  

```text
A falling Wu soldier caught in a shaft of pale light as a spear meant for him snaps aside, beneath a small riverside shrine wrapped in incense smoke. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 239. 二乔宅 / Qiao Sisters' Manor — `assets/art/cards/verdant_refuge.png`

*Card:* Allies have +1 armor.  
*Note:* Signature card of 大乔 Da Qiao: attach `assets/art/heroes_reserve/daqiao.png` as a reference so the face matches.

```text
A walled garden manor by a misty river at dusk, Da Qiao in jade silks at the moon gate as Wu guards stand watch along its walls and a small stone well glows with lantern light. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Batch 4 - Qun (black) (43)

**Qun (black) - Spells (19)**

### 240. 流矢 / Stray Arrow — `assets/art/cards/grazing_shot.png`

*Card:* Deal 2 damage to a unit in any lane.  

```text
A single black-fletched arrow streaking through drifting smoke over a chaotic battlefield toward a distant officer's helmet plume. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 241. 追亡逐北 / Hunt the Fleeing — `assets/art/cards/relentless_pursuit.png`

*Card:* Choose a unit in another lane. Move a random allied black hero from this lane to that lane. Deal 2 damage to the chosen unit.  

```text
A black-armoured warlord on horseback leaping over a ridge from one valley into the next in pursuit of scattering fugitives, dust and torn banners trailing behind him. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 242. 掷杯戏曹 / Toying with Cao Cao — `assets/art/cards/mana_drain.png`

*Card:* Give the enemy tower -2 mana this round and give your tower +2 mana this round.  
*Note:* Signature card of 左慈 Zuo Ci: attach `assets/art/heroes_reserve/zuoci.png` as a reference so the face matches. Also attach the Cao Cao card art (jmuy).

```text
Zuo Ci, a lean one-eyed Daoist, tossing a wine cup into the air above a banquet hall, where it turns into a white dove, while Cao Cao rises furious from his seat. The lamps on Cao Cao's side of the hall gutter out as those on Zuo Ci's side flare up. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 243. 临阵倒戈 / Spears Turned Inward — `assets/art/cards/lodestone_demolition.png`

*Card:* Deal damage to the enemy tower equal to the total armor of all enemies.  

```text
Heavily armoured soldiers wheeling around at a city gate and levelling their spears at their own walls and banners, their commander shouting in vain amid smoke; the heavier their armour, the harder their spears strike the wall. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 244. 纵火焚营 / Torch the Works — `assets/art/cards/dirty_deeds.png`

*Card:* Deal 2 damage to the enemy tower for each of its improvements.  

```text
Shadowed saboteurs slipping away from a burning palisade as watchtowers and siege works catch flame one after another behind them. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 245. 铸小钱 / Debased Coinage — `assets/art/cards/payday.png`

*Card:* Double your gold.  

```text
A palace courtyard furnace where toppled bronze statues are melted down and cascades of thin, cheap coins (blank, no characters) pour from the moulds, doubling into heaps. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 246. 讨曹檄文 / Proclamation Against Cao — `assets/art/cards/track.png`

*Card:* Give a hero +10 bounty until it dies.  
*Note:* Signature card of 袁绍 Yuan Shao: attach `assets/art/heroes_reserve/yuanshao.png` as a reference so the face matches.

```text
Yuan Shao in gilded black armour holding up a long proclamation scroll (blank, no legible text) before massed banners, heralds riding off with copies in every direction, and a single distant rider caught in a ring of red light as the hunted target. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 247. 急袭小沛 / Raid on Xiaopei — `assets/art/cards/ball_lightning.png`

*Card:* Move an allied black hero to an empty combat position in any lane.  
*Note:* Signature card of 高顺 Gao Shun: attach `assets/art/heroes_reserve/gaoshun.png` as a reference so the face matches.

```text
Gao Shun leading black-armoured shock troops with tall rectangular shields through a broken town gate at dawn, the defenders' banners falling. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 248. 麻沸散 / Mafei Powder — `assets/art/cards/heartstopper_aura.png`

*Card:* Permanently give a black hero "Before the action phase, deal 2 piercing damage to this hero's enemy neighbors."  
*Note:* Signature card of 华佗 Hua Tuo: attach `assets/art/heroes_reserve/huatuo.png` as a reference so the face matches.

```text
Hua Tuo in dark robes grinding powder in a bronze mortar as pale green vapour curls outward on both sides toward sagging, shadowy enemy soldiers. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 249. 酒池肉林 / Wine Pools, Meat Forests — `assets/art/cards/blood_rage.png`

*Card:* Silence a unit this round. Give it +4 attack this round.  
*Note:* Signature card of 董卓 Dong Zhuo: attach `assets/art/heroes_reserve/dongzhuo.png` as a reference so the face matches.

```text
Dong Zhuo, bloated and armoured, roaring drunk at a blood-red banquet table among overturned wine jars and roasted meat, with a guest beside him gagged into silence and smoke drifting behind. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 250. 截断粮道 / Cut the Supply Line — `assets/art/cards/arcane_censure.png`

*Card:* Permanently give the enemy tower -1 mana.  

```text
Black-clad raiders setting fire to a column of grain carts on a mountain road at dusk while the oxen bolt. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 251. 岘山伏击 / Ambush at Mount Xian — `assets/art/cards/gank.png`

*Card:* Choose an allied black hero. Choose another unit in any lane. They battle each other.  

```text
Archers and swordsmen springing out of a bamboo thicket on a mountain path at a lone galloping rider in a red headscarf. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 252. 衣带诏 / Belt Edict — `assets/art/cards/murder_plot.png`

*Card:* Give a black hero +8 attack this round. Choose a combat target for it.  

```text
Trembling hands unpicking a jade belt by candlelight to reveal a hidden blood-stained silk (no legible characters), a dagger lying beside it. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 253. 十八路诸侯 / Eighteen Lords — `assets/art/cards/coordinated_assault.png`

*Card:* Permanently give a black hero "After you play a black card, give this hero and its allied neighbors +2 attack this round."  

```text
A torch-lit ridge crowded with many warlords' plain, blank banners as generals raise their swords together toward a distant mountain pass. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 254. 纵兵劫掠 / Let Them Plunder — `assets/art/cards/collateral_damage.png`

*Card:* Permanently give a black hero +3 siege.  

```text
A mounted warlord watching his troops loot a burning city gate, carts heaped with plunder. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 255. 离间 / Estrangement — `assets/art/cards/winters_curse.png`

*Card:* Disarm a unit until the end of the round. Its allied neighbors battle it.  
*Note:* Signature card of 貂蝉 Diaochan: attach `assets/art/heroes_reserve/diaochan.png` as a reference so the face matches. Also attach the Lü Bu card art (phantom_assassin) and the Dong Zhuo portrait (dongzhuo.png).

```text
Diaochan, half-veiled under a moonlit pavilion, smiling faintly while two armoured warlords behind her, Lü Bu and Dong Zhuo, glare at each other with drawn blades. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 256. 火神之刃 / Blade of the Fire God — `assets/art/cards/assassinate.png`

*Card:* Deal 10 piercing damage to a unit in any lane.  
*Note:* Signature card of 祝融 Lady Zhurong: attach `assets/art/heroes_reserve/zhurong.png` as a reference so the face matches.

```text
Lady Zhurong at full gallop hurling a single burning knife that streaks like a comet across a dark jungle sky toward a distant target. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 257. 七擒七纵 / Seven Captures — `assets/art/cards/chain_frost.png`

*Card:* Deal 3 damage to a unit. Repeat 7 times: deal 3 damage to a random unit to its left or right. Get initiative.  
*Note:* Signature card of 孟获 Meng Huo: attach `assets/art/heroes_reserve/menghuo.png` as a reference so the face matches.

```text
Meng Huo in war paint bursting free of his ropes, a chain of snapped bonds and spirit-light whipping from soldier to soldier through the jungle mist, seven links long. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 258. 衔枚夜袭 / Silent Night Raid — `assets/art/cards/the_cover_of_night.png`

*Card:* Move an allied black hero to another lane. Give it +4 attack and +7 siege until the end of its next combat phase.  

```text
A column of shadowy soldiers with gag sticks in their mouths creeping under a moonless sky toward a sleeping fortress gate. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Qun (black) - Creeps (10)**

### 259. 游侠儿 / Young Knight-Errant — `assets/art/cards/assassins_apprentice.png`

*Card:* Marked Target: choose a combat target for Young Knight-Errant. Active ability; cooldown 1.  

```text
A young knight-errant swordsman in black with a short sword, crouched on a moonlit rooftop, eyes locked on an unseen target below. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 260. 投石兵 / Stone Slingers — `assets/art/cards/oglodi_catapult.png`

*Card:* Deal 2 piercing damage to the enemy tower before the action phase.  

```text
A ragged bandit whirling a leather sling overhead, a stone arcing away toward a distant wall, piles of river stones at his feet. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 261. 太平道人 / Taiping Preacher — `assets/art/cards/disciple_of_nevermore.png`

*Card:* Other allies have +2 attack and -2 armor.  

```text
A gaunt Taiping preacher in yellow-trimmed black robes lifting a bowl of talisman water as ash and incense smoke spiral upward around him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 262. 小黄门 / Palace Eunuch — `assets/art/cards/tyler_estate_censor.png`

*Card:* The enemy tower has -1 mana.  

```text
A sly palace eunuch in black court robes and a tall hat, clutching sealed memorials to his chest in flickering lantern light. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 263. 哀兵 / Grieving Host — `assets/art/cards/pit_fighter_of_quoidge.png`

*Card:* Permanently give Grieving Host +2 attack after an allied neighbor dies.  

```text
A scarred soldier in a white mourning headband over black armour, gripping a broken banner pole among fallen comrades, his grief hardening into fury. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 264. 白波贼 / White Wave Bandits — `assets/art/cards/oglodi_vandal.png`

*Card:* Play effect: deal 4 damage to the enemy tower.  

```text
A ragged White Wave bandit with a flaming torch and an axe, hacking at a studded town gate. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 265. 饥军 / Starving Horde — `assets/art/cards/ravenous_mass.png`

*Card:* Devour: condemn Starving Horde's allied neighbors. Permanently give Starving Horde their attack and health. Active ability; cooldown 1.  

```text
A gaunt mass of starving ragged soldiers pressing together into one hulking, menacing shape under a black sky, the hollow-eyed leader's face at its centre. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 266. 赵娥 / Zhao E the Avenger — `assets/art/cards/sister_of_the_veil.png`

*Card:* Blood Debt: choose a combat target for Zhao E the Avenger. Active ability; cooldown 1.  

```text
Zhao E, a young woman in plain mourning robes drawing back her veil, a short blade low at her side, stepping forward through a dusty market street toward her father's killer. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 267. 黑山贼 / Black Mountain Raider — `assets/art/cards/ravenhook.png`

*Card:* Highway Robbery: condemn a random item equipped by the unit blocking Black Mountain Raider. Get gold equal to that item's base cost. Active ability; cooldown 1.  

```text
A lean Black Mountain raider yanking a bronze-trimmed shield away from a victim with a hooked pole, sheer black cliffs behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 268. 许贡门客 / Xu Gong's Avengers — `assets/art/cards/assassins_shadow.png`

*Card:* Siege 5. Xu Gong's Avengers have -2 attack for each ally.  

```text
A hooded hunter-assassin crouched alone in a misty forest, bow drawn and spear slung across his back, no allies anywhere near him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

**Qun (black) - Improvements (14)**

### 269. 冲车 / Battering Ram — `assets/art/cards/trebuchets.png`

*Card:* Deal 2 piercing damage to the enemy tower before the action phase.  

```text
A hide-roofed battering ram cart slamming into a studded city gate, splinters and dust flying. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 270. 走为上 / Retreat Is Best — `assets/art/cards/escape_route.png`

*Card:* Slip Away: return an allied hero to the Fountain. Active ability; cooldown 1.  

```text
A cloaked warlord and a few riders slipping out of a back gate into thick night mist while torches blaze at the front of the camp. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 271. 二袁交恶 / Feud of the Yuans — `assets/art/cards/bitter_enemies.png`

*Card:* After the combat phase, remove a charge from Feud of the Yuans. Before the action phase, if it has no charges, deal 6 damage to both towers.  

```text
Two richly robed noblemen turning their backs on each other across a cracked courtyard, smoke rising from two fortresses beyond. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 272. 地道 / Sapper Tunnels — `assets/art/cards/unsupervised_artillery.png`

*Card:* Undermine: deal 4 piercing damage to the enemy tower. Only usable if there are no unblocked enemies. Active ability; cooldown 1.  

```text
A lamp-lit tunnel propped with timber beams running beneath a city wall, diggers hauling earth in baskets. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 273. 玉石俱焚 / Jade and Stone Burn — `assets/art/cards/assured_destruction.png`

*Card:* All heroes have +4 siege.  

```text
A city wall engulfed in roaring fire, jade ornaments and stone blocks cracking together in the heat. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 274. 诡道 / Way of Deception — `assets/art/cards/path_of_the_cunning.png`

*Card:* After you play a black card, permanently give a random ally +1 siege.  

```text
A dim war tent with a map table scattered with black stones and a hidden dagger, a strategist's shadow cast on the canvas. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 275. 郿坞 / Mei Fortress — `assets/art/cards/revtel_investments.png`

*Card:* Add a charge to Mei Fortress after the combat phase. Open the Vaults: get 4 gold for each charge, then condemn Mei Fortress. Active ability; cooldown 1.  

```text
A vault inside the high walls of Mei Fortress overflowing with gold, silk bolts and grain sacks under torchlight. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 276. 西园卖官 / Offices for Sale — `assets/art/cards/iron_fog_goldmine.png`

*Card:* Get 3 gold after the combat phase.  

```text
A eunuch weighing gold on bronze scales in a garden pavilion beside an official's hat and a blank seal. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 277. 先登洛阳 / First into Luoyang — `assets/art/cards/assault_ladders.png`

*Card:* Allies deal +2 damage when attacking a tower.  
*Note:* Signature card of 孙坚 Sun Jian: attach `assets/art/heroes_reserve/sunjian.png` as a reference so the face matches. Regenerate that portrait first (see *Hero portraits to regenerate*), because 孙坚 moved from Wu to Qun.

```text
Sun Jian in his red headscarf on a scaling ladder at the burning gate of Luoyang, black-armoured troops swarming up behind him. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 278. 歃血为盟 / Blood Oath — `assets/art/cards/the_oath.png`

*Card:* You can't play spells or creeps while this is the active lane. If there is an allied black hero in this lane, allies have +4 attack.  

```text
Armoured warlords gathered around an altar bowl of blood at night, raising their right hands to swear. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 279. 十常侍 / Ten Attendants — `assets/art/cards/the_tyler_estate.png`

*Card:* Both towers have -2 mana.  

```text
Ten eunuchs in black-and-purple robes whispering in a shadowed hall around an empty dragon throne. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 280. 床弩 / Bed Crossbow — `assets/art/cards/keenfolk_turret.png`

*Card:* Volley: deal 2 piercing damage to a unit. Active ability; cooldown 1.  

```text
A massive frame-mounted crossbow on a stone rampart, its bolt cocked and aimed down at the field. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 281. 黄天当立 / Yellow Heaven Rises — `assets/art/cards/march_of_the_machines.png`

*Card:* Before the action phase, if Yellow Heaven Rises has charges, remove one and deal 2 damage to the enemy tower and 2 damage to each enemy.  
*Note:* Signature card of 张角 Zhang Jiao: attach `assets/art/heroes_reserve/zhangjiao.png` as a reference so the face matches.

```text
Zhang Jiao on a stone altar raising his staff under a sky split between dead grey clouds and a blazing yellow dawn, yellow-turbaned crowds surging toward a city below. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 282. 井阑 / Siege Tower — `assets/art/cards/steam_cannon.png`

*Card:* Rain from Above: deal 4 piercing damage to a unit in any lane. Active ability; cooldown 1.  

```text
A tall wheeled wooden archery tower looming over a camp wall, archers on top loosing arrows downward. Vertical composition showing a dramatic moment, with the main action (fire, arrows, flood, ambush) concentrated in the upper 60% of the frame. Figures can be small within the scene. The bottom third fades into dark ink wash or mist because a text box covers it. A clear focal point, with nothing important at the edges. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Batch 5 - Items (40)

### 283. 杜康酒 / Du Kang Wine — `assets/art/cards/fountain_flask.png`

*Card:* Fully heal a unit.  

```text
Du Kang Wine, the legendary Han wine said to drown every care: a dark glazed wine jar sealed with plain red cloth (no characters), a bronze ladle and a steaming cup on a small lacquered stand, a soft restorative glow rising with the steam. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 284. 绝影 / Jueying Steed — `assets/art/cards/assassins_veil.png`

*Card:* Equipped hero gains +4 health. Jueying: choose a combat target for equipped hero. Active ability; cooldown 2.  
*Note:* Horse: uses the Dilu framing line. If a rider or stand appears, regenerate with 'riderless, no stand'.

```text
Jueying, the black warhorse whose name means Leaves No Shadow: a lean black steed in mid-gallop, so fast its outline smears into a trailing afterimage, an empty Han saddle with steel-blue tassels and no stirrups. A single subject hero shot, centred slightly above the middle and angled at three-quarters, against a plain ink-wash backdrop with a soft gold glow behind it. No rider, no hands and no people. The horse fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 285. 丹书铁券 / Iron Pardon Tablet — `assets/art/cards/revtel_signet_ring.png`

*Card:* Equipped hero gains +4 health and -3 bounty.  

```text
An iron pardon tablet: a curved, tile-shaped iron plaque inlaid with red cinnabar cloud patterns (no legible script), resting on folded silk inside an open lacquered case, a calm protective glow around it. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 286. 战鼓 / War Drums — `assets/art/cards/ristul_emblem.png`

*Card:* Equipped hero gains +4 health and -2 armor. The unit blocking equipped hero has -2 armor.  

```text
A huge red-lacquered war drum on a small wheeled stand with crossed drumsticks resting on its taut skin, ripples of sound bending the air in front of it. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 287. 爪黄飞电 / Flying Lightning — `assets/art/cards/phase_boots.png`

*Card:* Equipped hero gains +4 health. Lightning Dash: swap equipped hero with another ally. Active ability; cooldown 2.  
*Note:* Horse: uses the Dilu framing line. If a rider or stand appears, regenerate with 'riderless, no stand'.

```text
Flying Lightning, a white steed with golden-yellow hooves, leaping through a crackle of pale lightning, an empty Han saddle on its back and a faint double image showing it flashing from one spot to another. A single subject hero shot, centred slightly above the middle and angled at three-quarters, against a plain ink-wash backdrop with a soft gold glow behind it. No rider, no hands and no people. The horse fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 288. 大宛马 / Ferghana Horse — `assets/art/cards/stonehall_cloak.png`

*Card:* Equipped hero gains +4 health. Permanently give Ferghana Horse "Equipped hero gains +2 health" after the combat phase.  
*Note:* Horse: uses the Dilu framing line. If a rider or stand appears, regenerate with 'riderless, no stand'.

```text
A muscular chestnut Ferghana horse with a sweat-sheened coat standing proudly on a windswept frontier ridge, a battered empty saddle on its back and a faint rising golden glow showing it grows stronger every day. A single subject hero shot, centred slightly above the middle and angled at three-quarters, against a plain ink-wash backdrop with a soft gold glow behind it. No rider, no hands and no people. The horse fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 289. 蒺藜甲 / Caltrop Mail — `assets/art/cards/barbed_mail.png`

*Card:* Equipped hero gains +1 armor and +2 retaliate.  

```text
A lamellar cuirass bristling with short iron spikes shaped like caltrops, a broken spear tip lodged between the barbs. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 290. 流星锤 / Meteor Hammer — `assets/art/cards/demagicking_maul.png`

*Card:* Equipped hero gains +2 attack. Shooting Star: condemn a random enemy improvement. Only usable if equipped hero is unblocked. Active ability; cooldown 1.  

```text
A meteor hammer: a spiked iron ball on a long chain whirling in a wide arc around a stand, trailing sparks like a falling star. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 291. 百辟刀 / Hundred-Forged Blade — `assets/art/cards/stonehall_pike.png`

*Card:* Equipped hero gains +2 attack. Permanently give Hundred-Forged Blade "Equipped hero gains +1 attack" after the combat phase.  

```text
A gleaming Han saber with visible folded-steel patterns resting on an anvil, the blade glowing orange-hot, sparks rising from it. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 292. 明光铠 / Bright Light Armor — `assets/art/cards/stonehall_plate.png`

*Card:* Equipped hero gains +1 armor. Permanently give Bright Light Armor "Equipped hero gains +1 armor" after the combat phase.  

```text
A suit of Bright Light armour with two large polished round chest plates that blaze with reflected dawn sunlight, displayed on a wooden armour stand. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 293. 干将莫邪 / Ganjiang and Moye — `assets/art/cards/jasper_daggers.png`

*Card:* Equipped hero gains +2 attack and pierce. Equip effect: purge your opponent's effects from equipped hero.  

```text
Ganjiang and Moye, the legendary paired swords: a matched pair of straight double-edged jian, one dark and one bright, crossed above a stand, sparks scattering as their edges slice through a glowing thread. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 294. 锦袍 / Brocade Robe — `assets/art/cards/fur_lined_mantle.png`

*Card:* Equipped hero gains +8 health.  

```text
A richly embroidered crimson brocade war robe with a fur-trimmed collar, draped over a wooden stand. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 295. 鱼鳞甲 / Fish-Scale Armor — `assets/art/cards/chainmail.png`

*Card:* Equipped hero gains +2 armor.  

```text
A suit of overlapping iron fish-scale plates laced with red cord, displayed on a wooden stand. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 296. 诸葛连弩 / Zhuge Crossbow — `assets/art/cards/keenfolk_musket.png`

*Card:* Equipped hero gains +2 attack. Rapid Fire: deal 2 damage to a unit. Active ability; cooldown 2.  

```text
Zhuge's repeating crossbow: a wooden crossbow with a tall box magazine of bolts on top, resting on a stand as a single bolt streaks away from it as a line of light. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 297. 倚天剑 / Yitian Sword — `assets/art/cards/blink_dagger.png`

*Card:* Equipped hero gains +2 attack. Heaven's Reach: move equipped hero to another lane. Active ability; cooldown 2.  

```text
The Yitian Sword: a long straight jian with a jade guard floating point-up above a stand, a streak of light leaping from its tip and arcing far across the sky toward a distant horizon. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 298. 古锭刀 / Guding Blade — `assets/art/cards/blade_of_the_vigil.png`

*Card:* Equipped hero gains +2 attack and +4 cleave.  
*Note:* Sun Jian's sabre: attach the Sun Jian portrait (sunjian.png).

```text
The Guding Blade: a broad, heavy single-edged saber with a bronze ring pommel floating at an angle, a wide crescent of light trailing from its edge and ribbons streaming from the ring. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 299. 舍命甲 / Death-Sworn Armor — `assets/art/cards/bracers_of_sacrifice.png`

*Card:* Equipped hero gains +2 armor. Last Stand: deal 6 damage to equipped hero's enemy neighbors and condemn equipped hero. Active ability; cooldown 1.  

```text
A scarred black iron cuirass on a stand with a blood-red sash tied around it, burning embers swirling around it as if it is about to burst outward. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 300. 环首刀 / Ring-Pommel Saber — `assets/art/cards/poaching_knife.png`

*Card:* Equipped hero gains +2 attack. Get 5 gold after an enemy hero dies. Get 1 gold after an enemy creep dies.  

```text
A plain iron ring-pommel saber resting on a heap of copper coins (blank, no markings) and a folded, captured enemy banner. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 301. 大橹 / Great Pavise — `assets/art/cards/shield_of_basilius.png`

*Card:* Equipped hero gains +2 armor. Equipped hero's allied neighbors have +1 armor.  

```text
A tall rectangular wooden pavise painted with a snarling beast face (no writing), standing upright on a stand, a protective glow spilling past both its edges. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 302. 筒袖铠 / Sleeved Armor — `assets/art/cards/keenfolk_plate.png`

*Card:* Equipped hero gains +1 armor, and +1 armor for each of its attackers. Equipped hero's attackers have -1 armor.  

```text
A full-sleeved iron armour on a stand, a hail of crossbow bolts shattering against its tubular sleeves. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 303. 火油 / Fire Oil — `assets/art/cards/obliterating_orb.png`

*Card:* Condemn an improvement.  

```text
A sealed clay pot of fire oil with a burning rag fuse resting on a stand, flames licking upward from the fuse. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 304. 通关文牒 / Border Pass — `assets/art/cards/golden_ticket.png`

*Card:* Get a random item from the Secret Shop.  

```text
A bamboo-and-silk travel pass with a plain red seal impression (no characters), resting half-unrolled on a stand, a narrow band of warm golden light behind it like a gate swinging open. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 305. 白银狮子 / Silver Lion Armor — `assets/art/cards/rumusque_vestments.png`

*Card:* Equipped hero gains +1 armor. Lion's Breath: heal a unit 4. Active ability; cooldown 2.  

```text
Gleaming silver lamellar armour with a roaring lion-head breastplate on a stand, soft white healing light radiating from the lion's mouth. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 306. 贯石斧 / Stone-Splitting Axe — `assets/art/cards/red_mist_maul.png`

*Card:* Equipped hero gains +2 attack and +5 siege.  

```text
A massive long-hafted battle axe buried in a cracked block of fortress masonry, chips of stone flying. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 307. 太平要术 / Way of Great Peace — `assets/art/cards/ring_of_tarrasque.png`

*Card:* Equipped hero gains +4 health and +6 regeneration.  

```text
The Way of Great Peace: an ancient yellow silk scroll unrolled above a stand to reveal glowing abstract talisman patterns (no legible characters), healing mist rising from a bowl of talisman water beside it. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 308. 孟德新书 / Mengde's New Book — `assets/art/cards/cloak_of_endless_carnage.png`

*Card:* Equipped hero gains +8 health. Draw a card after an allied neighbor of equipped hero dies.  

```text
A thick bound bamboo-slip military manual lying open on a stand beside a candle and a broken arrow, the slips blank with no legible characters. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 309. 招魂幡 / Soul-Calling Banner — `assets/art/cards/book_of_the_dead.png`

*Card:* Equipped hero gains +4 health. Add a charge to Soul-Calling Banner after an allied Foot Soldier dies. Call the Dead: summon a Ghost Soldier for each charge, then remove all charges. Active ability; cooldown 2.  
*Note:* Its active summons Ghost Soldiers; keep the wisps faint so it still reads as an object.

```text
A long tattered white-and-black funeral banner on a staff, its streamers drifting in grave mist as pale spirit wisps gather around it. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 310. 浑天仪 / Armillary Sphere — `assets/art/cards/claszureme_hourglass.png`

*Card:* Equipped hero gains +4 health. Whenever your opponent draws a card, give that card +1 lock if equipped hero is in any lane.  

```text
A bronze armillary sphere of interlocking rings on dragon-shaped supports, star points glowing as its rings turn. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 311. 玄武盾 / Black Tortoise Shield — `assets/art/cards/shield_of_aquila.png`

*Card:* Equipped hero gains +2 armor. Equipped hero's allied neighbors have +3 armor.  

```text
A round dark-bronze shield embossed with a tortoise entwined by a serpent, projecting a faint shell-shaped barrier to both sides. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 312. 赤兔 / Red Hare — `assets/art/cards/heros_cape.png`

*Card:* Equipped hero gains +16 health.  
*Note:* Horse: uses the Dilu framing line. Lü Bu's horse, so you can attach the Lü Bu card art (phantom_assassin) for the saddle colours.

```text
Red Hare, the finest horse of the age: a magnificent blood-red warhorse rearing on a hilltop at sunset, its mane like flame, an ornate empty saddle and bridle. A single subject hero shot, centred slightly above the middle and angled at three-quarters, against a plain ink-wash backdrop with a soft gold glow behind it. No rider, no hands and no people. The horse fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 313. 玄甲 / Black Iron Armor — `assets/art/cards/platemail.png`

*Card:* Equipped hero gains +4 armor.  

```text
A complete suit of dark blackened-iron lamellar armour with a full-face helmet on a stand, imposing in torchlight. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 314. 仁王盾 / Benevolent King Shield — `assets/art/cards/seraphim_shield.png`

*Card:* Equipped hero gains +2 armor. All units have -2 attack.  

```text
A broad bronze shield engraved with a serene king's face, a soft golden aura spreading out from it in calm waves. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 315. 狮盔 / Lion Helm — `assets/art/cards/shivas_guard.png`

*Card:* Equipped hero gains +2 armor. Lion's Dread: permanently give a unit and its allied neighbors -2 attack. Active ability; cooldown 2.  
*Note:* Ma Chao's helm: attach the Ma Chao portrait (machao.png).

```text
A silver helm shaped like a roaring lion's head with a white plume on a dark stand, a wave of dread rippling out from its open jaws. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 316. 紫金冠 / Purple-Gold Crown — `assets/art/cards/helm_of_the_dominator.png`

*Card:* Equipped hero gains +3 armor. Overawe: get control of an enemy creep. Active ability; cooldown 2.  
*Note:* Lü Bu's crown: attach the Lü Bu card art (phantom_assassin).

```text
An ornate purple-and-gold warrior's crown with two long pheasant-tail plumes on a dark stand, glowing in candlelight. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 317. 龙袍 / Dragon Robe — `assets/art/cards/vesture_of_the_tyrant.png`

*Card:* Equipped hero gains +3 armor and rapid deployment. Your tower has +3 armor.  

```text
A golden imperial dragon robe displayed on a stand atop a fortified city tower, the wind lifting its hem. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 318. 丈八蛇矛 / Serpent Spear — `assets/art/cards/wingfall_hammer.png`

*Card:* Equipped hero gains +4 attack. Rally: give equipped hero and its allied neighbors +X regeneration this round, where X is half its attack. Active ability; cooldown 1.  
*Note:* Zhang Fei's weapon: attach the Zhang Fei card art (axe) so the blade matches.

```text
The Eighteen-Foot Serpent Spear: a long spear with a wavy serpent-shaped blade planted upright, a warm red rallying glow pulsing out from it. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 319. 传国玉玺 / Imperial Jade Seal — `assets/art/cards/shop_deed.png`

*Card:* Each item in your Secret Shop costs X less gold, where X is its base cost.  
*Note:* Match the seal in the Sun Jian portrait. ChatGPT likes to carve characters on seals; erase any with the edit tool.

```text
The Imperial Jade Seal: a square white-jade seal crowned with five coiled dragons, one corner chipped and patched in gold, glowing on a small pile of treasure. Its base is turned away and blank, with no characters. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 320. 虎符 / Tiger Tally — `assets/art/cards/horn_of_the_alpha.png`

*Card:* Equipped hero gains +4 health. Mobilize: summon a Tower Ship. Active ability; cooldown 2.  
*Note:* Its active summons a Tower Ship, so the ship should echo the Tower Ship card art (thunderhide_pack).

```text
Two halves of a gold-inlaid bronze tiger tally joining together above a stand, a faint mist-shape of a multi-decked tower ship rising behind them. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 321. 八门金锁 / Eight-Gate Lock — `assets/art/cards/nyctashas_guard.png`

*Card:* Equipped hero gains +1 armor. Lock the Gates: move equipped hero's enemy neighbors to random other lanes. Active ability; cooldown 1.  

```text
An octagonal bronze formation disc engraved with eight gate openings and swirling paths (abstract patterns, no characters), floating above a stand as small streaks of light shoot out through its gates in different directions. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 322. 方天画戟 / Sky Piercer — `assets/art/cards/apotheosis_blade.png`

*Card:* Equipped hero gains +8 attack and +4 siege. Condemn each unit equipped hero deals battle damage to. Halberd Sweep: condemn enemy improvements. Condemn each item equipped by the unit blocking equipped hero. Active ability; cooldown 1.  
*Note:* Lü Bu's weapon: attach the Lü Bu card art (phantom_assassin) so the halberd matches.

```text
Sky Piercer: an ornate crescent-bladed halberd with red tassels, floating point-up against a thunderous sky, lightning playing along its edge. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: burnished gold and bronze, warm candlelight, a museum-quality treasured artifact, otherwise a neutral muted ink-wash palette. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Batch 6 - Tokens (5)

### 323. 木兽 / Wooden Beast — `assets/art/cards/loyal_beast.png`

*Card:* When Wooden Beast deals battle damage to a unit, permanently give that unit -1 attack.  
*Note:* Token. Generate it before 火兽破阵 so the war-beasts match.

```text
A carved wooden war-beast with a lion-like head, painted crimson and banded in bronze, jaws open and gears visible at its joints, lunging forward. Treat the beast as the single main figure, its head in the upper-middle. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 324. 屯田兵 / Farm Soldier — `assets/art/cards/plague_ward.png`

*Card:* Before the action phase, deal 2 piercing damage to a random enemy neighbor of Farm Soldier.  
*Note:* Token summoned by 屯兵淮南. Make it before that spell.

```text
A weathered Wei soldier-farmer in a straw rain cape over dark lamellar, thrusting a sharpened hoe-spear, flooded paddies behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 325. 拒马 / Spiked Barricade — `assets/art/cards/roseleaf_wall.png`

*Card:* Creep: 0 attack, 0 armor, 8 health.  
*Note:* Token from 濡须筑坞. An object, so it uses the item framing line with the Wu faction line.

```text
A sturdy wooden cheval-de-frise of crossed sharpened stakes lashed with rope on a muddy riverbank, mist behind it and no figures. A single object hero shot, centred slightly above the middle and angled at three-quarters. It floats or rests on a simple stand against a plain ink-wash backdrop with a soft gold glow behind it. No hands or characters. The object fills about 60% of the frame width, and the bottom third is empty mist. Faction palette: jade green and teal, wet lacquered wood, river mist and reflections on the Yangtze, war-junk sails and reeds, a mood of naval pride. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 326. 阴兵 / Ghost Soldier — `assets/art/cards/zombie.png`

*Card:* Creep: 2 attack, 0 armor, 2 health.  
*Note:* Token summoned by 泸水残兵 and 招魂幡. Plain and simple, like the Foot Soldier.

```text
A pale, translucent foot soldier in rotted Han armour marching out of grave mist with a rusted spear, his face hollow but calm. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 327. 饿虎 / Hungry Tiger — `assets/art/cards/hound_of_war.png`

*Card:* Creep: 2 attack, 0 armor, 1 health.  
*Note:* Token summoned by 驱虎吞狼. An animal, so it stands in for the main figure.

```text
A lean, snarling tiger with ribs showing, crouched to spring out of tall grass, smoke drifting behind it. Treat the tiger as the single main figure, its head in the upper-middle. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Hero portraits to regenerate (3)

These three heroes changed faction in the catalog mapping, so their reserve portraits carry the wrong faction palette. Regenerate each one over its existing file in `assets/art/heroes_reserve/`, attaching the current portrait so the face stays the same. (`ART_PROMPTS.md` still lists them under their old factions in *Future heroes*.)

### 328. 孙尚香 / Sun Shangxiang — `assets/art/heroes_reserve/sunshangxiang.png`

*Card:* Sun Shangxiang has no active or passive ability.  
*Note:* Was Wu (green), now Shu (red): crimson replaces her jade-green ribbons and armour. Keep her face from the current portrait (attach it). Then make 孙夫人城 (Lady Sun's Fort) in Batch 1.

```text
Lady Sun Shangxiang, the martial princess who married Liu Bei and stood with Shu: a spirited young woman with a bold, confident smile and bright eyes, her hair tied high with crimson ribbons. She wears fitted crimson and white light armour over a short battle robe, with a bow slung across her back and a pair of straight short swords held ready in both hands. A wedding-red silk sash at her waist marks her marriage to Liu Bei. Peach petals drift past a plain red silk banner behind her in warm sunset light. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: crimson and vermilion with jade-green accents, a warm sunset glow, peach blossoms and red silk banners, a mood of righteous brotherhood. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 329. 陈宫 / Chen Gong — `assets/art/heroes_reserve/chengong.png`

*Card:* Clear Counsel: after you play a blue card, there is a 50% chance to restore 2 mana.  
*Note:* Was Qun (black), now Wei (blue): the Zhongmou magistrate who freed Cao Cao, in indigo instead of black and plum. Keep his face from the current portrait (attach it). Then make 捉放曹 (Catch and Release) in Batch 2.

```text
Chen Gong, the upright county magistrate who freed the fugitive Cao Cao and became his first strategist: a lean, sharp-featured man in his thirties with a thin beard, a furrowed brow and an unbending gaze. He wears dark indigo and steel-blue magistrate's robes with a simple official's cap, and holds an iron key ring in one hand and a half-unrolled blank bamboo scroll in the other. Behind him a county wall and a jail gate stand in cold moonlight under a frost-grey sky. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: deep indigo and steel blue, dark iron lamellar armour, cold moonlight, disciplined ranks and frost-grey sky, a mood of imperial authority and calculation. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

### 330. 孙坚 / Sun Jian — `assets/art/heroes_reserve/sunjian.png`

*Card:* Raider's Bane: Sun Jian deals +4 damage when attacking a tower.  
*Note:* Was Wu (green), now Qun (black): black-and-bronze armour, burning Luoyang behind him; the red headscarf, sabre and seal stay. Keep his face from the current portrait (attach it). Then make 先登洛阳 (First into Luoyang) in Batch 4.

```text
Sun Jian, the Tiger of Jiangdong, an ambitious coalition warlord who seized the imperial seal from the ruins of Luoyang: a bold, broad-shouldered warrior with a confident grin, short beard and fierce eyes, a crimson headscarf tied over his topknot. He wears black-lacquered and bronze lamellar armour with a tiger-pelt mantle and grips an ancient broad-bladed sabre at his side. In his raised other hand he holds a small, softly glowing jade imperial seal topped with a coiled dragon, seen from the side with no markings visible. Smoke and embers from the burning capital rise behind him. Vertical portrait composition. A single main figure, shown from the waist or three-quarters up. The face and chest sit in the upper-middle third of the frame, centred horizontally. Leave the top 12% as quiet background (sky or mist) and keep the bottom 35% simple with low detail (ground, mist, robes). Weapons and limbs must not touch or cross the frame edges. The background is soft and less detailed than the figure. Faction palette: ink black and bruised purple, curling smoke and embers, torn banners, poison-green highlights, a mood of ambition, treachery and chaos. Painterly illustration with anime influence: clean expressive faces, confident linework and soft cel-shaded figures. The figures sit on a traditional Chinese ink-wash (shuimo) background of layered grey-black washes, dry-brush mountains and drifting mist on warm aged rice paper. Small gold-leaf accents on armour edges, embroidery and sparks. Dramatic cinematic rim light against deep shadow, a restrained earthy palette lifted by one strong faction colour, Eastern Han dynasty historical detail. Rendered as polished trading card game art in a single consistent style. Do not include any text, letters, numbers, Chinese characters, calligraphy, seals, stamps, signatures, watermarks, logos, card frames, borders or UI elements. No modern objects. Do not imitate any specific video game, anime franchise or living artist's style. No extra fingers, no duplicated faces, no cropped heads. 1024x1536 portrait.
```

## Checklist

Tick each box as you go: **Made** (generated and accepted), **No text** (no glyphs anywhere), **Crop** (passes the crop check), **Saved** (PNG at the repo path).

| # | 中文 / English | File | Batch | Made | No text | Crop | Saved |
|---|---|---|---|---|---|---|---|
| 112 | 耒阳断案 / Leiyang Verdicts | `assets/art/cards/kraken_shell.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 113 | 九伐中原 / Nine Northern Campaigns | `assets/art/cards/double_edge.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 114 | 拖刀计 / Trailing-Blade Feint | `assets/art/cards/poised_to_strike.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 115 | 张松献图 / Zhang Song's Map | `assets/art/cards/new_orders.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 116 | 傅彤断后 / Fu Tong's Rearguard | `assets/art/cards/fight_through_the_pain.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 117 | 七进七出 / Seven Charges Through | `assets/art/cards/whirling_death.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 118 | 廖化先锋 / Liao Hua Leads | `assets/art/cards/heroic_resolve.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 119 | 夜战葭萌关 / Night Duel at Jiameng | `assets/art/cards/duel.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 120 | 骂死王朗 / Scolding Wang Lang | `assets/art/cards/pick_a_fight.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 121 | 虎父无犬子 / Tiger's Cubs | `assets/art/cards/rising_anger.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 122 | 智取瓦口 / Taking Wakou Pass | `assets/art/cards/smash_their_defenses.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 123 | 法正举旗 / Fa Zheng's Signal | `assets/art/cards/spot_weakness.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 124 | 盘蛇谷 / Coiled Serpent Valley | `assets/art/cards/rend_armor.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 125 | 镇守汉中 / Hold Hanzhong | `assets/art/cards/enrage.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 126 | 五虎上将 / Five Tiger Generals | `assets/art/cards/clear_the_deck.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 127 | 回马枪 / Turnback Spear | `assets/art/cards/sucker_punch.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 128 | 兴复汉室 / Restore the Han | `assets/art/cards/tresdins_standards.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 129 | 烈弓 / Fierce Bow | `assets/art/cards/viscous_nasal_goo.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 130 | 攻心为上 / Win Their Hearts | `assets/art/cards/crippling_blow.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 131 | 火烧博望 / Fire at Bowang | `assets/art/cards/raze.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 132 | 温酒斩华雄 / Ere the Wine Cools | `assets/art/cards/enough_magic.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 133 | 鸡肋 / Chicken Rib | `assets/art/cards/routed.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 134 | 髀肉之叹 / Lament of Idle Thighs | `assets/art/cards/gods_strength.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 135 | 火兽破阵 / Fire Beasts Break Ranks | `assets/art/cards/primal_roar.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 136 | 飞军天降 / Flying Army Descends | `assets/art/cards/spring_the_trap.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 137 | 桃园结义 / Peach Garden Oath | `assets/art/cards/time_of_triumph.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 138 | 东州兵 / Dongzhou Exiles | `assets/art/cards/mercenary_exiles.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 139 | 绊马索兵 / Snare-Rope Troops | `assets/art/cards/hellbear_crippler.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 140 | 蒲元刀匠 / Pu Yuan's Smiths | `assets/art/cards/smeevil_armsmaster.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 141 | 涿郡义兵 / Zhuo Volunteers | `assets/art/cards/rebel_instigator.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 142 | 牙门旗手 / Yamen Standard Bearer | `assets/art/cards/legion_standard_bearer.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 143 | 虎步军 / Tiger-Step Elite | `assets/art/cards/stonehall_elite.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 144 | 连弩手 / Repeating Crossbowmen | `assets/art/cards/ogre_corpse_tosser.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 145 | 泸水残兵 / Lu River Veterans | `assets/art/cards/cursed_satyr.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 146 | 西凉铁骑 / Xiliang Iron Cavalry | `assets/art/cards/red_mist_pillager.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 147 | 木牛流马 / Wooden Ox | `assets/art/cards/keenfolk_golem.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 148 | 板楯蛮 / Banshun Shieldmen | `assets/art/cards/marrowfell_brawler.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 149 | 滚木礌石 / Logs and Boulders | `assets/art/cards/burning_oil.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 150 | 蜀道 / Road to Shu | `assets/art/cards/path_of_the_bold.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 151 | 成都武库 / Chengdu Arsenal | `assets/art/cards/temple_of_war.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 152 | 阵前斗将 / Clash of Champions | `assets/art/cards/grand_melee.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 153 | 将计就计 / Turn the Tables | `assets/art/cards/nether_ward.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 154 | 孙夫人城 / Lady Sun's Fort | `assets/art/cards/steel_reinforcement.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 155 | 白帝城 / Baidi Citadel | `assets/art/cards/the_omexe_arena.png` | 1 | [ ] | [ ] | [ ] | [ ] |
| 156 | 虎豹骑冲阵 / Tiger-Leopard Charge | `assets/art/cards/strafing_run.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 157 | 割发代首 / Hair for a Head | `assets/art/cards/diabolic_revelation.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 158 | 激将法 / Provocation | `assets/art/cards/ventriloquy.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 159 | 割须弃袍 / Cut Beard, Shed Robe | `assets/art/cards/cunning_plan.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 160 | 梦中杀人 / Killing in My Dreams | `assets/art/cards/whispers_of_madness.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 161 | 煮酒论英雄 / Heroes Over Plum Wine | `assets/art/cards/rolling_storm.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 162 | 拔矢啖睛 / Eating His Own Eye | `assets/art/cards/frostbite.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 163 | 千金悬赏 / Thousand-Gold Bounty | `assets/art/cards/wrath_of_gold.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 164 | 徐晃援樊 / Xu Huang's Relief | `assets/art/cards/better_late_than_never.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 165 | 缓兵之计 / Stalling Tactics | `assets/art/cards/buying_time.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 166 | 调虎离山 / Lure the Tiger | `assets/art/cards/compel.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 167 | 宁我负人 / Let Me Wrong the World | `assets/art/cards/at_any_cost.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 168 | 屯兵淮南 / Garrison the Huai | `assets/art/cards/sow_venom.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 169 | 分兵疾进 / Split and Advance | `assets/art/cards/divided_we_stand.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 170 | 仿造木牛 / Copy the Wooden Ox | `assets/art/cards/and_one_for_me.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 171 | 捉放曹 / Catch and Release | `assets/art/cards/astral_imprisonment.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 172 | 抹书间韩 / The Smudged Letter | `assets/art/cards/self_sabotage.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 173 | 驱虎吞狼 / Tiger Against Wolf | `assets/art/cards/prey_on_the_weak.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 174 | 声东击西 / Feint East, Strike West | `assets/art/cards/arcane_assault.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 175 | 虚张声势 / Decoy Army | `assets/art/cards/fog_of_war.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 176 | 洛神赋 / Ode to the Luo Goddess | `assets/art/cards/eclipse.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 177 | 掷短戟 / Hail of Short Halberds | `assets/art/cards/mystic_flare.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 178 | 千里请战 / Thousand-Li Petition | `assets/art/cards/lost_in_time.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 179 | 三日五百里 / Three-Day Forced March | `assets/art/cards/call_the_reserves.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 180 | 二虎竞食 / Two Tigers, One Prey | `assets/art/cards/friendly_fire.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 181 | 十面埋伏 / Ambush on Ten Sides | `assets/art/cards/remote_detonation.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 182 | 辽来止啼 / Liao Is Coming | `assets/art/cards/echo_slam.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 183 | 火烧乌巢 / Burning of Wuchao | `assets/art/cards/bolt_of_damocles.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 184 | 敢死士 / Dare-to-Die Men | `assets/art/cards/relentless_zombie.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 185 | 典农校尉 / Agrarian Colonel | `assets/art/cards/satyr_magician.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 186 | 管辂 / Guan Lu the Diviner | `assets/art/cards/troll_soothsayer.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 187 | 曹植 / Cao Zhi | `assets/art/cards/incarnation_of_selemene.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 188 | 驿站 / Post Station | `assets/art/cards/messenger_rookery.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 189 | 斥候营 / Scout Camp | `assets/art/cards/watchtower.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 190 | 坚壁清野 / Walls and Bare Fields | `assets/art/cards/fractured_timeline.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 191 | 太学 / Imperial Academy | `assets/art/cards/path_of_the_wise.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 192 | 十胜十败 / Ten Wins, Ten Losses | `assets/art/cards/ignite.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 193 | 月旦评 / Monthly Appraisals | `assets/art/cards/howling_mind.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 194 | 铜雀台 / Bronze Sparrow Terrace | `assets/art/cards/aghanims_sanctum.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 195 | 虎卫营 / Tiger Guard Camp | `assets/art/cards/barracks.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 196 | 强弩营 / Crossbow Battery | `assets/art/cards/conflagration.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 197 | 陷马坑 / Horse Pitfalls | `assets/art/cards/glyph_of_confusion.png` | 2 | [ ] | [ ] | [ ] | [ ] |
| 198 | 金蝉脱壳 / Cicada Sheds Its Shell | `assets/art/cards/juke.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 199 | 奋身护主 / Shield the Lord | `assets/art/cards/aphotic_shield.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 200 | 列盾相护 / Shields Together | `assets/art/cards/defend_the_weak.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 201 | 擂鼓 / Pounding Drums | `assets/art/cards/bellow.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 202 | 蒙冲掩护 / Mengchong Cover | `assets/art/cards/iron_branch_protection.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 203 | 犒赏三军 / Reward the Army | `assets/art/cards/rumusque_blessing.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 204 | 诈降火船 / Fire Ship Feint | `assets/art/cards/viper_strike.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 205 | 激昂 / Rousing Fervor | `assets/art/cards/empower.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 206 | 神亭酣斗 / Duel at Shenting | `assets/art/cards/ion_shell.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 207 | 濡须筑坞 / Fortify Ruxu | `assets/art/cards/defensive_bloom.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 208 | 琴瑟和鸣 / Zither in Harmony | `assets/art/cards/allseeing_ones_favor.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 209 | 筑石头城 / Raise Stone City | `assets/art/cards/restoration_effort.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 210 | 养精蓄锐 / Rest and Recover | `assets/art/cards/soul_of_spring.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 211 | 临江祓禊 / River Purification | `assets/art/cards/cleansing_rite.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 212 | 卑辞骄敌 / Lull with Flattery | `assets/art/cards/caught_unprepared.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 213 | 偷梁换柱 / Swap the Beams | `assets/art/cards/steal_strength.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 214 | 江南瘴疠 / Southern Miasma | `assets/art/cards/corrosive_mist.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 215 | 长江天堑 / The Yangtze Barrier | `assets/art/cards/divine_intervention.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 216 | 疑城退敌 / Phantom Ramparts | `assets/art/cards/intimidation.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 217 | 水土不服 / Ill-Suited to the South | `assets/art/cards/curse_of_atrophy.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 218 | 指囷相赠 / Granary Gift | `assets/art/cards/hand_of_god.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 219 | 天命所归 / Mandate of Heaven | `assets/art/cards/divine_purpose.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 220 | 丹阳兵 / Danyang Diehards | `assets/art/cards/vhoul_martyr.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 221 | 祖茂 / Zu Mao | `assets/art/cards/rebel_decoy.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 222 | 吴越铸师 / Wu-Yue Armorsmith | `assets/art/cards/smeevil_blacksmith.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 223 | 吴钩剑客 / Wu Hook Duelist | `assets/art/cards/satyr_duelist.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 224 | 山越蛮兵 / Shanyue Berserkers | `assets/art/cards/rampaging_hellbear.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 225 | 陆家部曲 / Lu Clan Retainers | `assets/art/cards/roseleaf_druid.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 226 | 越巫 / Yue Shaman | `assets/art/cards/selfish_cleric.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 227 | 漕船队 / Grain Barge Fleet | `assets/art/cards/revtel_convoy.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 228 | 无难军 / Wunan Guard | `assets/art/cards/champion_of_the_ancient.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 229 | 杏林医仙 / Apricot Grove Healer | `assets/art/cards/roseleaf_rejuvenator.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 230 | 诸葛瑾 / Zhuge Jin | `assets/art/cards/emissary_of_the_quorum.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 231 | 飞云大船 / Feiyun Flagship | `assets/art/cards/thunderhide_alpha.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 232 | 江防烽燧 / River Beacons | `assets/art/cards/unearthed_secrets.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 233 | 鱼米之乡 / Land of Fish and Rice | `assets/art/cards/path_of_the_dreamer.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 234 | 水师操练 / Fleet Drills | `assets/art/cards/mist_of_avernus.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 235 | 以逸待劳 / Wait Out the Weary | `assets/art/cards/homefield_advantage.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 236 | 定都建业 / Capital at Jianye | `assets/art/cards/selemenes_favor.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 237 | 伤兵营 / Field Infirmary | `assets/art/cards/altar_of_the_mad_moon.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 238 | 吉人天相 / Heaven Protects | `assets/art/cards/cheating_death.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 239 | 二乔宅 / Qiao Sisters' Manor | `assets/art/cards/verdant_refuge.png` | 3 | [ ] | [ ] | [ ] | [ ] |
| 240 | 流矢 / Stray Arrow | `assets/art/cards/grazing_shot.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 241 | 追亡逐北 / Hunt the Fleeing | `assets/art/cards/relentless_pursuit.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 242 | 掷杯戏曹 / Toying with Cao Cao | `assets/art/cards/mana_drain.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 243 | 临阵倒戈 / Spears Turned Inward | `assets/art/cards/lodestone_demolition.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 244 | 纵火焚营 / Torch the Works | `assets/art/cards/dirty_deeds.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 245 | 铸小钱 / Debased Coinage | `assets/art/cards/payday.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 246 | 讨曹檄文 / Proclamation Against Cao | `assets/art/cards/track.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 247 | 急袭小沛 / Raid on Xiaopei | `assets/art/cards/ball_lightning.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 248 | 麻沸散 / Mafei Powder | `assets/art/cards/heartstopper_aura.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 249 | 酒池肉林 / Wine Pools, Meat Forests | `assets/art/cards/blood_rage.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 250 | 截断粮道 / Cut the Supply Line | `assets/art/cards/arcane_censure.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 251 | 岘山伏击 / Ambush at Mount Xian | `assets/art/cards/gank.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 252 | 衣带诏 / Belt Edict | `assets/art/cards/murder_plot.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 253 | 十八路诸侯 / Eighteen Lords | `assets/art/cards/coordinated_assault.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 254 | 纵兵劫掠 / Let Them Plunder | `assets/art/cards/collateral_damage.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 255 | 离间 / Estrangement | `assets/art/cards/winters_curse.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 256 | 火神之刃 / Blade of the Fire God | `assets/art/cards/assassinate.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 257 | 七擒七纵 / Seven Captures | `assets/art/cards/chain_frost.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 258 | 衔枚夜袭 / Silent Night Raid | `assets/art/cards/the_cover_of_night.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 259 | 游侠儿 / Young Knight-Errant | `assets/art/cards/assassins_apprentice.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 260 | 投石兵 / Stone Slingers | `assets/art/cards/oglodi_catapult.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 261 | 太平道人 / Taiping Preacher | `assets/art/cards/disciple_of_nevermore.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 262 | 小黄门 / Palace Eunuch | `assets/art/cards/tyler_estate_censor.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 263 | 哀兵 / Grieving Host | `assets/art/cards/pit_fighter_of_quoidge.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 264 | 白波贼 / White Wave Bandits | `assets/art/cards/oglodi_vandal.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 265 | 饥军 / Starving Horde | `assets/art/cards/ravenous_mass.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 266 | 赵娥 / Zhao E the Avenger | `assets/art/cards/sister_of_the_veil.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 267 | 黑山贼 / Black Mountain Raider | `assets/art/cards/ravenhook.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 268 | 许贡门客 / Xu Gong's Avengers | `assets/art/cards/assassins_shadow.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 269 | 冲车 / Battering Ram | `assets/art/cards/trebuchets.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 270 | 走为上 / Retreat Is Best | `assets/art/cards/escape_route.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 271 | 二袁交恶 / Feud of the Yuans | `assets/art/cards/bitter_enemies.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 272 | 地道 / Sapper Tunnels | `assets/art/cards/unsupervised_artillery.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 273 | 玉石俱焚 / Jade and Stone Burn | `assets/art/cards/assured_destruction.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 274 | 诡道 / Way of Deception | `assets/art/cards/path_of_the_cunning.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 275 | 郿坞 / Mei Fortress | `assets/art/cards/revtel_investments.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 276 | 西园卖官 / Offices for Sale | `assets/art/cards/iron_fog_goldmine.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 277 | 先登洛阳 / First into Luoyang | `assets/art/cards/assault_ladders.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 278 | 歃血为盟 / Blood Oath | `assets/art/cards/the_oath.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 279 | 十常侍 / Ten Attendants | `assets/art/cards/the_tyler_estate.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 280 | 床弩 / Bed Crossbow | `assets/art/cards/keenfolk_turret.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 281 | 黄天当立 / Yellow Heaven Rises | `assets/art/cards/march_of_the_machines.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 282 | 井阑 / Siege Tower | `assets/art/cards/steam_cannon.png` | 4 | [ ] | [ ] | [ ] | [ ] |
| 283 | 杜康酒 / Du Kang Wine | `assets/art/cards/fountain_flask.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 284 | 绝影 / Jueying Steed | `assets/art/cards/assassins_veil.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 285 | 丹书铁券 / Iron Pardon Tablet | `assets/art/cards/revtel_signet_ring.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 286 | 战鼓 / War Drums | `assets/art/cards/ristul_emblem.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 287 | 爪黄飞电 / Flying Lightning | `assets/art/cards/phase_boots.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 288 | 大宛马 / Ferghana Horse | `assets/art/cards/stonehall_cloak.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 289 | 蒺藜甲 / Caltrop Mail | `assets/art/cards/barbed_mail.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 290 | 流星锤 / Meteor Hammer | `assets/art/cards/demagicking_maul.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 291 | 百辟刀 / Hundred-Forged Blade | `assets/art/cards/stonehall_pike.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 292 | 明光铠 / Bright Light Armor | `assets/art/cards/stonehall_plate.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 293 | 干将莫邪 / Ganjiang and Moye | `assets/art/cards/jasper_daggers.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 294 | 锦袍 / Brocade Robe | `assets/art/cards/fur_lined_mantle.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 295 | 鱼鳞甲 / Fish-Scale Armor | `assets/art/cards/chainmail.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 296 | 诸葛连弩 / Zhuge Crossbow | `assets/art/cards/keenfolk_musket.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 297 | 倚天剑 / Yitian Sword | `assets/art/cards/blink_dagger.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 298 | 古锭刀 / Guding Blade | `assets/art/cards/blade_of_the_vigil.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 299 | 舍命甲 / Death-Sworn Armor | `assets/art/cards/bracers_of_sacrifice.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 300 | 环首刀 / Ring-Pommel Saber | `assets/art/cards/poaching_knife.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 301 | 大橹 / Great Pavise | `assets/art/cards/shield_of_basilius.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 302 | 筒袖铠 / Sleeved Armor | `assets/art/cards/keenfolk_plate.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 303 | 火油 / Fire Oil | `assets/art/cards/obliterating_orb.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 304 | 通关文牒 / Border Pass | `assets/art/cards/golden_ticket.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 305 | 白银狮子 / Silver Lion Armor | `assets/art/cards/rumusque_vestments.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 306 | 贯石斧 / Stone-Splitting Axe | `assets/art/cards/red_mist_maul.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 307 | 太平要术 / Way of Great Peace | `assets/art/cards/ring_of_tarrasque.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 308 | 孟德新书 / Mengde's New Book | `assets/art/cards/cloak_of_endless_carnage.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 309 | 招魂幡 / Soul-Calling Banner | `assets/art/cards/book_of_the_dead.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 310 | 浑天仪 / Armillary Sphere | `assets/art/cards/claszureme_hourglass.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 311 | 玄武盾 / Black Tortoise Shield | `assets/art/cards/shield_of_aquila.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 312 | 赤兔 / Red Hare | `assets/art/cards/heros_cape.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 313 | 玄甲 / Black Iron Armor | `assets/art/cards/platemail.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 314 | 仁王盾 / Benevolent King Shield | `assets/art/cards/seraphim_shield.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 315 | 狮盔 / Lion Helm | `assets/art/cards/shivas_guard.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 316 | 紫金冠 / Purple-Gold Crown | `assets/art/cards/helm_of_the_dominator.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 317 | 龙袍 / Dragon Robe | `assets/art/cards/vesture_of_the_tyrant.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 318 | 丈八蛇矛 / Serpent Spear | `assets/art/cards/wingfall_hammer.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 319 | 传国玉玺 / Imperial Jade Seal | `assets/art/cards/shop_deed.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 320 | 虎符 / Tiger Tally | `assets/art/cards/horn_of_the_alpha.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 321 | 八门金锁 / Eight-Gate Lock | `assets/art/cards/nyctashas_guard.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 322 | 方天画戟 / Sky Piercer | `assets/art/cards/apotheosis_blade.png` | 5 | [ ] | [ ] | [ ] | [ ] |
| 323 | 木兽 / Wooden Beast | `assets/art/cards/loyal_beast.png` | 6 | [ ] | [ ] | [ ] | [ ] |
| 324 | 屯田兵 / Farm Soldier | `assets/art/cards/plague_ward.png` | 6 | [ ] | [ ] | [ ] | [ ] |
| 325 | 拒马 / Spiked Barricade | `assets/art/cards/roseleaf_wall.png` | 6 | [ ] | [ ] | [ ] | [ ] |
| 326 | 阴兵 / Ghost Soldier | `assets/art/cards/zombie.png` | 6 | [ ] | [ ] | [ ] | [ ] |
| 327 | 饿虎 / Hungry Tiger | `assets/art/cards/hound_of_war.png` | 6 | [ ] | [ ] | [ ] | [ ] |
| 328 | 孙尚香 / Sun Shangxiang | `assets/art/heroes_reserve/sunshangxiang.png` | Hero regenerate | [ ] | [ ] | [ ] | [ ] |
| 329 | 陈宫 / Chen Gong | `assets/art/heroes_reserve/chengong.png` | Hero regenerate | [ ] | [ ] | [ ] | [ ] |
| 330 | 孙坚 / Sun Jian | `assets/art/heroes_reserve/sunjian.png` | Hero regenerate | [ ] | [ ] | [ ] | [ ] |

## Hero art copy table

The 38 catalog heroes reuse their existing reserve portraits. When a hero is added to the game, copy its portrait to the card path (then run `python tools/optimize_art.py`). Do the three marked **regenerate** only after making their new portrait above.

| Card id | Hero | Faction | Copy from | Copy to | Portrait |
|---|---|---|---|---|---|
| 10021 | 姜维 / Jiang Wei | Shu (red) | `assets/art/heroes_reserve/jiangwei.png` | `assets/art/cards/centaur_warrunner.png` | ready |
| 10022 | 赵云 / Zhao Yun | Shu (red) | `assets/art/heroes_reserve/zhaoyun.png` | `assets/art/cards/timbersaw.png` | ready |
| 10024 | 庞统 / Pang Tong | Shu (red) | `assets/art/heroes_reserve/pangtong.png` | `assets/art/cards/tidehunter.png` | ready |
| 10029 | 黄月英 / Huang Yueying | Shu (red) | `assets/art/heroes_reserve/huangyueying.png` | `assets/art/cards/beastmaster.png` | ready |
| 10030 | 黄忠 / Huang Zhong | Shu (red) | `assets/art/heroes_reserve/huangzhong.png` | `assets/art/cards/bristleback.png` | ready |
| 10048 | 诸葛亮 / Zhuge Liang | Shu (red) | `assets/art/heroes_reserve/zhugeliang.png` | `assets/art/cards/pugna.png` | ready |
| 10052 | 孙尚香 / Sun Shangxiang | Shu (red) | `assets/art/heroes_reserve/sunshangxiang.png` | `assets/art/cards/mazzie.png` | **regenerate** (was Wu) |
| 10054 | 刘备 / Liu Bei | Shu (red) | `assets/art/heroes_reserve/liubei.png` | `assets/art/cards/sven.png` | ready |
| 10069 | 马超 / Ma Chao | Shu (red) | `assets/art/heroes_reserve/machao.png` | `assets/art/cards/legion_commander.png` | ready |
| 10070 | 魏延 / Wei Yan | Shu (red) | `assets/art/heroes_reserve/weiyan.png` | `assets/art/cards/ursa.png` | ready |
| 10001 | 邓艾 / Deng Ai | Wei (blue) | `assets/art/heroes_reserve/dengai.png` | `assets/art/cards/venomancer.png` | ready |
| 10004 | 夏侯渊 / Xiahou Yuan | Wei (blue) | `assets/art/heroes_reserve/xiahouyuan.png` | `assets/art/cards/meepo.png` | ready |
| 10006 | 甄姬 / Zhen Ji | Wei (blue) | `assets/art/heroes_reserve/zhenji.png` | `assets/art/cards/luna.png` | ready |
| 10031 | 荀彧 / Xun Yu | Wei (blue) | `assets/art/heroes_reserve/xunyu.png` | `assets/art/cards/kanna.png` | ready |
| 10033 | 张辽 / Zhang Liao | Wei (blue) | `assets/art/heroes_reserve/zhangliao.png` | `assets/art/cards/earthshaker.png` | ready |
| 10043 | 郭嘉 / Guo Jia | Wei (blue) | `assets/art/heroes_reserve/guojia.png` | `assets/art/cards/ogre_magi.png` | ready |
| 10046 | 陈宫 / Chen Gong | Wei (blue) | `assets/art/heroes_reserve/chengong.png` | `assets/art/cards/outworld_devourer.png` | **regenerate** (was Qun) |
| 10053 | 许褚 / Xu Chu | Wei (blue) | `assets/art/heroes_reserve/xuchu.png` | `assets/art/cards/prellex.png` | ready |
| 10062 | 典韦 / Dian Wei | Wei (blue) | `assets/art/heroes_reserve/dianwei.png` | `assets/art/cards/skywrath_mage.png` | ready |
| 10064 | 夏侯惇 / Xiahou Dun | Wei (blue) | `assets/art/heroes_reserve/xiahoudun.png` | `assets/art/cards/crystal_maiden.png` | ready |
| 10016 | 周泰 / Zhou Tai | Wu (green) | `assets/art/heroes_reserve/zhoutai.png` | `assets/art/cards/abaddon.png` | ready |
| 10017 | 鲁肃 / Lu Su | Wu (green) | `assets/art/heroes_reserve/lusu.png` | `assets/art/cards/chen.png` | ready |
| 10028 | 黄盖 / Huang Gai | Wu (green) | `assets/art/heroes_reserve/huanggai.png` | `assets/art/cards/viper.png` | ready |
| 10036 | 大乔 / Da Qiao | Wu (green) | `assets/art/heroes_reserve/daqiao.png` | `assets/art/cards/enchantress.png` | ready |
| 10044 | 小乔 / Xiao Qiao | Wu (green) | `assets/art/heroes_reserve/xiaoqiao.png` | `assets/art/cards/omniknight.png` | ready |
| 10056 | 陆逊 / Lu Xun | Wu (green) | `assets/art/heroes_reserve/luxun.png` | `assets/art/cards/treant_protector.png` | ready |
| 10067 | 孙策 / Sun Ce | Wu (green) | `assets/art/heroes_reserve/sunce.png` | `assets/art/cards/magnus.png` | ready |
| 10068 | 太史慈 / Taishi Ci | Wu (green) | `assets/art/heroes_reserve/taishici.png` | `assets/art/cards/dark_seer.png` | ready |
| 10010 | 貂蝉 / Diaochan | Qun (black) | `assets/art/heroes_reserve/diaochan.png` | `assets/art/cards/winter_wyvern.png` | ready |
| 10018 | 董卓 / Dong Zhuo | Qun (black) | `assets/art/heroes_reserve/dongzhuo.png` | `assets/art/cards/bloodseeker.png` | ready |
| 10023 | 袁绍 / Yuan Shao | Qun (black) | `assets/art/heroes_reserve/yuanshao.png` | `assets/art/cards/bounty_hunter.png` | ready |
| 10025 | 张角 / Zhang Jiao | Qun (black) | `assets/art/heroes_reserve/zhangjiao.png` | `assets/art/cards/tinker.png` | ready |
| 10038 | 孟获 / Meng Huo | Qun (black) | `assets/art/heroes_reserve/menghuo.png` | `assets/art/cards/lich.png` | ready |
| 10050 | 祝融 / Lady Zhurong | Qun (black) | `assets/art/heroes_reserve/zhurong.png` | `assets/art/cards/sniper.png` | ready |
| 10058 | 孙坚 / Sun Jian | Qun (black) | `assets/art/heroes_reserve/sunjian.png` | `assets/art/cards/sorla_khan.png` | **regenerate** (was Wu) |
| 10059 | 华佗 / Hua Tuo | Qun (black) | `assets/art/heroes_reserve/huatuo.png` | `assets/art/cards/necrophos.png` | ready |
| 10060 | 左慈 / Zuo Ci | Qun (black) | `assets/art/heroes_reserve/zuoci.png` | `assets/art/cards/lion.png` | ready |
| 10536 | 高顺 / Gao Shun | Qun (black) | `assets/art/heroes_reserve/gaoshun.png` | `assets/art/cards/storm_spirit.png` | ready |

To copy all 38 at once from the project root (Git Bash):

```bash
cp assets/art/heroes_reserve/jiangwei.png assets/art/cards/centaur_warrunner.png
cp assets/art/heroes_reserve/zhaoyun.png assets/art/cards/timbersaw.png
cp assets/art/heroes_reserve/pangtong.png assets/art/cards/tidehunter.png
cp assets/art/heroes_reserve/huangyueying.png assets/art/cards/beastmaster.png
cp assets/art/heroes_reserve/huangzhong.png assets/art/cards/bristleback.png
cp assets/art/heroes_reserve/zhugeliang.png assets/art/cards/pugna.png
cp assets/art/heroes_reserve/sunshangxiang.png assets/art/cards/mazzie.png
cp assets/art/heroes_reserve/liubei.png assets/art/cards/sven.png
cp assets/art/heroes_reserve/machao.png assets/art/cards/legion_commander.png
cp assets/art/heroes_reserve/weiyan.png assets/art/cards/ursa.png
cp assets/art/heroes_reserve/dengai.png assets/art/cards/venomancer.png
cp assets/art/heroes_reserve/xiahouyuan.png assets/art/cards/meepo.png
cp assets/art/heroes_reserve/zhenji.png assets/art/cards/luna.png
cp assets/art/heroes_reserve/xunyu.png assets/art/cards/kanna.png
cp assets/art/heroes_reserve/zhangliao.png assets/art/cards/earthshaker.png
cp assets/art/heroes_reserve/guojia.png assets/art/cards/ogre_magi.png
cp assets/art/heroes_reserve/chengong.png assets/art/cards/outworld_devourer.png
cp assets/art/heroes_reserve/xuchu.png assets/art/cards/prellex.png
cp assets/art/heroes_reserve/dianwei.png assets/art/cards/skywrath_mage.png
cp assets/art/heroes_reserve/xiahoudun.png assets/art/cards/crystal_maiden.png
cp assets/art/heroes_reserve/zhoutai.png assets/art/cards/abaddon.png
cp assets/art/heroes_reserve/lusu.png assets/art/cards/chen.png
cp assets/art/heroes_reserve/huanggai.png assets/art/cards/viper.png
cp assets/art/heroes_reserve/daqiao.png assets/art/cards/enchantress.png
cp assets/art/heroes_reserve/xiaoqiao.png assets/art/cards/omniknight.png
cp assets/art/heroes_reserve/luxun.png assets/art/cards/treant_protector.png
cp assets/art/heroes_reserve/sunce.png assets/art/cards/magnus.png
cp assets/art/heroes_reserve/taishici.png assets/art/cards/dark_seer.png
cp assets/art/heroes_reserve/diaochan.png assets/art/cards/winter_wyvern.png
cp assets/art/heroes_reserve/dongzhuo.png assets/art/cards/bloodseeker.png
cp assets/art/heroes_reserve/yuanshao.png assets/art/cards/bounty_hunter.png
cp assets/art/heroes_reserve/zhangjiao.png assets/art/cards/tinker.png
cp assets/art/heroes_reserve/menghuo.png assets/art/cards/lich.png
cp assets/art/heroes_reserve/zhurong.png assets/art/cards/sniper.png
cp assets/art/heroes_reserve/sunjian.png assets/art/cards/sorla_khan.png
cp assets/art/heroes_reserve/huatuo.png assets/art/cards/necrophos.png
cp assets/art/heroes_reserve/zuoci.png assets/art/cards/lion.png
cp assets/art/heroes_reserve/gaoshun.png assets/art/cards/storm_spirit.png
```



import SwiftUI

// --- 基础数据定义 ---
enum GameStage { case language, difficulty, playing }
enum CellStatus { case hidden, revealed, flagged }

struct Cell {
    var isMine = false
    var neighborMineCount = 0
    var status = CellStatus.hidden
}

enum Difficulty: String, CaseIterable {
    case easy = "简单", medium = "中等", hard = "困难", insane = "特别困难"
    var config: (size: Int, mines: Int, color: Color) {
        switch self {
        case .easy: return (10, 10, .green)
        case .medium: return (15, 20, .orange)
        case .hard: return (20, 30, .red)
        case .insane: return (25, 50, .purple)
        }
    }
}

// --- 游戏主界面 ---
struct ContentView: View {
    @State private var stage: GameStage = .language
    @State private var grid: [Cell] = []
    @State private var selectedDifficulty: Difficulty = .easy
    @State private var gameOver = false
    @State private var gameWon = false
    @State private var isFirstClick = true
    @State private var selectedLang: LangInfo = allLanguages[1] // 默认中文（简体）

    var currentConfig: (size: Int, mines: Int, color: Color) { selectedDifficulty.config }

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()
            
            // 根据阶段显示不同页面
            switch stage {
            case .language:
                languagePickerView
            case .difficulty:
                difficultyPickerView
            case .playing:
                gameBoardView
            }
            
            // ★ 改进的全屏结算层：确保语言一致并全屏覆盖 ★
            if (gameOver || gameWon) && stage == .playing {
                resultOverlay
                    .transition(.opacity)
                    .zIndex(100) // 确保在最顶层
            }
        }
        .frame(minWidth: 700, minHeight: 850)
    }

    // 1. 语言选择页
    var languagePickerView: some View {
        VStack(spacing: 20) {
            Text("SELECT LANGUAGE").font(.system(size: 30, weight: .black)).padding(.top)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    ForEach(allLanguages, id: \.id) { lang in
                        Button(action: {
                            self.selectedLang = lang
                            withAnimation { self.stage = .difficulty }
                        }) {
                            HStack {
                                Text(lang.flag)
                                Text(lang.name).font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .padding(10).background(Color.white).cornerRadius(8).shadow(radius: 1)
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }
        }
    }

    // 2. 难度选择页
    var difficultyPickerView: some View {
        VStack(spacing: 40) {
            Text(selectedLang.name).font(.title2).foregroundColor(.secondary)
            Text(selectedLang.localLabel("select_diff")).font(.system(size: 35, weight: .black))
            
            VStack(spacing: 15) {
                ForEach(Difficulty.allCases, id: \.self) { diff in
                    Button(action: {
                        self.selectedDifficulty = diff
                        resetGame()
                        withAnimation { self.stage = .playing }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedLang.localDiff(diff)).font(.title2).bold()
                                Text("\(diff.config.size)x\(diff.config.size) | \(diff.config.mines) Mines").font(.caption)
                            }
                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                        }
                        .padding().frame(width: 320).background(diff.config.color).foregroundColor(.white).cornerRadius(12)
                    }.buttonStyle(.plain)
                }
            }
            Button(selectedLang.localLabel("back")) { withAnimation { stage = .language } }.font(.headline)
        }
    }

    // 3. 游戏主阵列
    var gameBoardView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { withAnimation { stage = .difficulty } }) {
                    Image(systemName: "arrow.left.circle.fill").font(.largeTitle)
                }.buttonStyle(.plain).foregroundColor(currentConfig.color)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(selectedLang.title).font(.title.bold()).foregroundColor(currentConfig.color)
                    Text(selectedLang.localDiff(selectedDifficulty)).monospaced()
                }
            }.padding()

            HStack(spacing: 40) {
                Label("\(currentConfig.mines)", systemImage: "bomb.fill")
                Label("\(grid.filter { !$0.isMine && $0.status == .hidden }.count)", systemImage: "square.grid.3x3.fill")
                Label("\(grid.filter { $0.status == .flagged }.count)", systemImage: "app.fill").foregroundColor(.red)
            }.font(.system(.headline, design: .monospaced)).padding(.bottom, 10)

            Spacer()

            let cellSize = CGFloat(min(600 / currentConfig.size, 28))
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 1), count: currentConfig.size)

            ScrollView([.horizontal, .vertical]) {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(0..<grid.count, id: \.self) { index in
                        ZStack {
                            Rectangle()
                                .fill(grid[index].status == .revealed ? Color.white : (grid[index].status == .flagged ? Color.red : Color(white: 0.8)))
                                .frame(width: cellSize, height: cellSize)
                                .overlay(Rectangle().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
                            
                            if grid[index].status == .revealed {
                                if grid[index].isMine { Text("💣").font(.system(size: cellSize * 0.7)) }
                                else if grid[index].neighborMineCount > 0 {
                                    Text("\(grid[index].neighborMineCount)")
                                        .font(.system(size: cellSize * 0.6, weight: .bold))
                                        .foregroundColor([.blue, .green, .red, .purple, .orange, .cyan, .black, .brown][min(grid[index].neighborMineCount-1, 7)])
                                }
                            }
                        }
                        .onTapGesture { clickCell(index: index) }
                        .onLongPressGesture(minimumDuration: 0.25) { flagCell(index: index) }
                    }
                }.padding(20).background(Color.black.opacity(0.1)).cornerRadius(12)
            }
            Spacer()
            Button(action: resetGame) { Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 50)).foregroundColor(currentConfig.color) }.buttonStyle(.plain).padding(.bottom, 30)
        }
    }

    // 4. ★ 结算界面（全屏并支持翻译）★
    var resultOverlay: some View {
        ZStack {
            Color(gameWon ? .green : .red).opacity(0.95).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text(selectedLang.localLabel(gameWon ? "win" : "lose"))
                    .font(.system(size: 60, weight: .black))
                    .foregroundColor(.white)
                
                VStack(spacing: 15) {
                    Button(action: { resetGame() }) {
                        Text(selectedLang.localLabel("retry"))
                            .font(.title2).bold().frame(width: 250, height: 60)
                            .background(Color.white).foregroundColor(gameWon ? .green : .red).cornerRadius(15)
                    }.buttonStyle(.plain)
                    
                    Button(action: { withAnimation { stage = .difficulty } }) {
                        Text(selectedLang.localLabel("menu"))
                            .font(.headline).frame(width: 250, height: 50)
                            .background(Color.white.opacity(0.2)).foregroundColor(.white).cornerRadius(15)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // 核心逻辑
    func resetGame() { withAnimation { gameOver = false; gameWon = false; isFirstClick = true; grid = Array(repeating: Cell(), count: currentConfig.size * currentConfig.size) } }
    func flagCell(index: Int) { if !gameOver && !gameWon && grid[index].status != .revealed { NSSound(named: "Pop")?.play(); grid[index].status = (grid[index].status == .flagged) ? .hidden : .flagged } }
    func clickCell(index: Int) {
        if gameOver || gameWon || grid[index].status != .hidden { return }
        if isFirstClick { generateMines(excluding: index); isFirstClick = false }
        if grid[index].isMine { grid.indices.forEach { if grid[$0].isMine { grid[$0].status = .revealed } }; withAnimation { gameOver = true } }
        else { reveal(index: index); if grid.filter({!$0.isMine}).allSatisfy({$0.status == .revealed}) { withAnimation { gameWon = true } } }
    }
    func generateMines(excluding index: Int) {
        let total = currentConfig.size * currentConfig.size
        var placed = 0
        while placed < currentConfig.mines {
            let r = Int.random(in: 0..<total)
            if r != index && !grid[r].isMine { grid[r].isMine = true; placed += 1 }
        }
        for i in 0..<total { if !grid[i].isMine { grid[i].neighborMineCount = countAround(i) } }
    }
    func reveal(index: Int) {
        guard index >= 0 && index < grid.count && grid[index].status == .hidden else { return }
        grid[index].status = .revealed
        if grid[index].neighborMineCount == 0 { getNeighbors(index).forEach { reveal(index: $0) } }
    }
    func countAround(_ i: Int) -> Int { getNeighbors(i).filter { grid[$0].isMine }.count }
    func getNeighbors(_ i: Int) -> [Int] {
        let s = currentConfig.size, r = i / s, c = i % s
        var n = [Int]()
        for dr in -1...1 { for dc in -1...1 { let nr = r+dr, nc = c+dc; if nr>=0 && nr<s && nc>=0 && nc<s && !(dr==0 && dc==0) { n.append(nr*s+nc) } } }
        return n
    }
}

// --- 5. 增强版语言包（带翻译映射） ---
struct LangInfo: Hashable {
    let id: String
    let name: String
    let flag: String
    
    var title: String { name.contains("中文") ? "扫雷" : (id == "ja" ? "マインスイーパ" : "Minesweeper") }
    
    // 翻译映射表
    func localLabel(_ key: String) -> String {
        let isChinese = name.contains("中文")
        switch key {
        case "select_diff": return isChinese ? "选择难度" : "Select Difficulty"
        case "back": return isChinese ? "返回" : "Back"
        case "win": return isChinese ? "挑战成功" : "MISSION CLEAR"
        case "lose": return isChinese ? "触发地雷" : "GAME OVER"
        case "retry": return isChinese ? "再试一次" : "RETRY"
        case "menu": return isChinese ? "返回菜单" : "MAIN MENU"
        default: return ""
        }
    }
    
    func localDiff(_ diff: Difficulty) -> String {
        let isChinese = name.contains("中文")
        if !isChinese { return diff.rawValue == "简单" ? "Easy" : (diff.rawValue == "中等" ? "Medium" : (diff.rawValue == "困难" ? "Hard" : "Insane")) }
        return diff.rawValue
    }
}

let allLanguages: [LangInfo] = [
    LangInfo(id: "en", name: "English", flag: "🇺🇸"), LangInfo(id: "zh_cn", name: "中文（简体）", flag: "🇨🇳"),
    LangInfo(id: "zh_tw", name: "中文（台湾）", flag: "🇹🇼"), LangInfo(id: "zh_hk", name: "中文（香港）", flag: "🇭🇰"),
    LangInfo(id: "es", name: "Español", flag: "🇪🇸"), LangInfo(id: "hi", name: "हिन्दी", flag: "🇮🇳"),
    LangInfo(id: "ar", name: "العربية", flag: "🇸🇦"), LangInfo(id: "fr", name: "Français", flag: "🇫🇷"),
    LangInfo(id: "bn", name: "বাংলা", flag: "🇧🇩"), LangInfo(id: "ru", name: "Русский", flag: "🇷🇺"),
    LangInfo(id: "pt", name: "Português", flag: "🇵🇹"), LangInfo(id: "ur", name: "اردو", flag: "🇵🇰"),
    LangInfo(id: "id", name: "Indonesia", flag: "🇮🇩"), LangInfo(id: "de", name: "Deutsch", flag: "🇩🇪"),
    LangInfo(id: "ja", name: "日本語", flag: "🇯🇵"), LangInfo(id: "sw", name: "Kiswahili", flag: "🇰🇪"),
    LangInfo(id: "mr", name: "मराठी", flag: "🇮🇳"), LangInfo(id: "te", name: "తెలుగు", flag: "🇮🇳"),
    LangInfo(id: "tr", name: "Türkçe", flag: "🇹🇷"), LangInfo(id: "ta", name: "தமிழ்", flag: "🇮🇳"),
    LangInfo(id: "vi", name: "Tiếng Việt", flag: "🇻🇳"), LangInfo(id: "ko", name: "한국어", flag: "🇰🇷"),
    LangInfo(id: "it", name: "Italiano", flag: "🇮🇹"), LangInfo(id: "th", name: "ไทย", flag: "🇹🇭"),
    LangInfo(id: "gu", name: "ગુજરાતી", flag: "🇮🇳"), LangInfo(id: "fa", name: "فارسی", flag: "🇮🇷"),
    LangInfo(id: "kn", name: "ಕನ್ನಡ", flag: "🇮🇳"), LangInfo(id: "pa", name: "ਪੰਜਾਬੀ", flag: "🇮🇳"),
    LangInfo(id: "ml", name: "മലയാളം", flag: "🇮🇳"), LangInfo(id: "or", name: "ଓଡ଼ିଆ", flag: "🇮🇳"),
    LangInfo(id: "my", name: "မြန်မာ", flag: "🇲🇲"), LangInfo(id: "pl", name: "Polski", flag: "🇵🇱"),
    LangInfo(id: "uk", name: "Українська", flag: "🇺🇦"), LangInfo(id: "nl", name: "Nederlands", flag: "🇳🇱"),
    LangInfo(id: "ro", name: "Română", flag: "🇷🇴"), LangInfo(id: "el", name: "Ελληνικά", flag: "🇬🇷"),
    LangInfo(id: "cs", name: "Čeština", flag: "🇨🇿"), LangInfo(id: "hu", name: "Magyar", flag: "🇭🇺"),
    LangInfo(id: "sv", name: "Svenska", flag: "🇸🇪"), LangInfo(id: "fi", name: "Suomi", flag: "🇫🇮"),
    LangInfo(id: "da", name: "Dansk", flag: "🇩🇰"), LangInfo(id: "no", name: "Norsk", flag: "🇳🇴"),
    LangInfo(id: "sk", name: "Slovenčina", flag: "🇸🇰"), LangInfo(id: "bg", name: "Български", flag: "🇧🇬"),
    LangInfo(id: "sr", name: "Српски", flag: "🇷🇸"), LangInfo(id: "hr", name: "Hrvatski", flag: "🇭🇷"),
    LangInfo(id: "bs", name: "Bosanski", flag: "🇧🇦"), LangInfo(id: "sl", name: "Slovenščina", flag: "🇸🇮"),
    LangInfo(id: "lt", name: "Lietuvių", flag: "🇱🇹"), LangInfo(id: "lv", name: "Latviešu", flag: "🇱🇻"),
    LangInfo(id: "et", name: "Eesti", flag: "🇪🇪"), LangInfo(id: "is", name: "Íslenska", flag: "🇮🇸"),
    LangInfo(id: "ga", name: "Gaeilge", flag: "🇮🇪"), LangInfo(id: "cy", name: "Cymraeg", flag: "🏴󠁧󠁢󠁷󠁬󠁳󠁿"),
    LangInfo(id: "gd", name: "Gàidhlig", flag: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"), LangInfo(id: "sq", name: "Shqip", flag: "🇦🇱"),
    LangInfo(id: "mk", name: "Македонски", flag: "🇲🇰"), LangInfo(id: "hy", name: "Հայերեն", flag: "🇦🇲"),
    LangInfo(id: "ka", name: "ქართული", flag: "🇬🇪"), LangInfo(id: "he", name: "עברית", flag: "🇮🇱"),
    LangInfo(id: "yo", name: "Yorùbá", flag: "🇳🇬"), LangInfo(id: "ha", name: "Hausa", flag: "🇳🇬"),
    LangInfo(id: "ig", name: "Igbo", flag: "🇳🇬"), LangInfo(id: "zu", name: "isiZulu", flag: "🇿🇦"),
    LangInfo(id: "xh", name: "isiXhosa", flag: "🇿🇦"), LangInfo(id: "af", name: "Afrikaans", flag: "🇿🇦"),
    LangInfo(id: "am", name: "አማርኛ", flag: "🇪🇹"), LangInfo(id: "so", name: "Soomaali", flag: "🇸🇴"),
    LangInfo(id: "ne", name: "नेपाली", flag: "🇳🇵"), LangInfo(id: "si", name: "සිංහල", flag: "🇱🇰"),
    LangInfo(id: "lo", name: "ລາວ", flag: "🇱🇦"), LangInfo(id: "km", name: "ខ្មែរ", flag: "🇰🇭"),
    LangInfo(id: "mn", name: "Монгол", flag: "🇲🇳"), LangInfo(id: "kk", name: "Қазақ", flag: "🇰🇿"),
    LangInfo(id: "uz", name: "Oʻzbek", flag: "🇺🇿"), LangInfo(id: "tk", name: "Türkmen", flag: "🇹🇲"),
    LangInfo(id: "ky", name: "Кыргызча", flag: "🇰🇬"), LangInfo(id: "tg", name: "Тоҷиκӣ", flag: "🇹🇯"),
    LangInfo(id: "az", name: "Azərbaycanca", flag: "🇦🇿"), LangInfo(id: "eu", name: "Euskara", flag: "🇪🇸"),
    LangInfo(id: "ca", name: "Català", flag: "🇪🇸"), LangInfo(id: "gl", name: "Galego", flag: "🇪🇸"),
    LangInfo(id: "la", name: "Latina", flag: "🇻🇦"), LangInfo(id: "eo", name: "Esperanto", flag: "🌍")
]


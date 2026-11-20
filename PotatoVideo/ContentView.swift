import SwiftUI

private enum Theme {
    static let ink = Color(red: 25 / 255, green: 52 / 255, blue: 59 / 255)
    static let muted = Color(red: 76 / 255, green: 104 / 255, blue: 113 / 255)
    static let coral = Color(red: 1, green: 110 / 255, blue: 88 / 255)
    static let teal = Color(red: 35 / 255, green: 169 / 255, blue: 154 / 255)
}

struct FrostedBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("Background")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .blur(radius: 22)
                .overlay(Color.white.opacity(0.47))
                .clipped()
        }
        .ignoresSafeArea()
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: VideoStore
    @State private var editingHistory = false
    @State private var confirmingDelete = false
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        NavigationStack {
            ZStack {
                FrostedBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 10) {
                            Image("Dog")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 50)
                                .frame(width: 60, height: 60)
                                .background(.white.opacity(0.7))
                                .clipShape(Circle())
                            Text("土豆视频")
                                .font(.system(size: 27, weight: .bold))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                        HStack(spacing: 10) {
                            TextField("你想看什么", text: $store.query)
                                .focused($searchFocused)
                                .submitLabel(.search)
                                .onSubmit(runSearch)
                                .padding(.horizontal, 15)
                                .frame(height: 54)
                                .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
                                .onChange(of: store.query) { value in
                                    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        store.clearSearch()
                                        editingHistory = false
                                    }
                                }
                            Button("搜索", action: runSearch)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 82, height: 54)
                                .background(Theme.coral, in: RoundedRectangle(cornerRadius: 15))
                        }

                        NavigationLink(destination: FavoritesView()) {
                            Text("我的收藏")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Theme.teal, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .buttonStyle(.plain)

                        if store.showingResults {
                            resultsSection
                        } else if !store.history.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 36)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("删除全部搜索历史？", isPresented: $confirmingDelete) {
                Button("全部删除", role: .destructive) {
                    store.clearHistory()
                    editingHistory = false
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("搜索历史")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                if editingHistory {
                    Button("全部删除") { confirmingDelete = true }
                        .foregroundStyle(Theme.muted)
                    Button("完成") { editingHistory = false }
                } else {
                    Button { editingHistory = true } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("编辑搜索历史")
                }
            }
            .foregroundStyle(Theme.ink)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(store.history, id: \.self) { item in
                    HStack {
                        Button {
                            if !editingHistory {
                                store.query = item
                                runSearch()
                            }
                        } label: {
                            Text(item)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if editingHistory {
                            Button { store.deleteHistory(item) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.muted)
                            }
                            .accessibilityLabel("删除" + item)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 48)
                }
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("搜索结果")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if store.isSearching && !store.results.isEmpty {
                    ProgressView().tint(Theme.coral)
                }
            }
            if store.results.isEmpty {
                if store.isSearching {
                    ProgressView()
                        .tint(Theme.coral)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    Text(store.searchMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                }
            } else {
                ForEach(store.results.sorted { $0.title < $1.title }) { video in
                    NavigationLink(destination: DetailView(video: video)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.system(size: 16, weight: .medium))
                            if !video.details.isEmpty {
                                Text(video.details)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func runSearch() {
        searchFocused = false
        store.search(store.query)
    }
}

struct DetailView: View {
    let video: Video
    var returnTitle = "返回搜索结果"
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VideoStore
    @State private var episodes: [Episode] = []
    @State private var selectedEpisode: Episode?
    @State private var isLoading = true
    @State private var message = ""
    @State private var showingFolderPicker = false
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var favoriteFeedback = ""

    private let columns = [GridItem(.adaptive(minimum: 54, maximum: 54), spacing: 27)]

    var body: some View {
        ZStack {
            FrostedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button(returnTitle) { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.teal, in: RoundedRectangle(cornerRadius: 16))
                    Text(video.title)
                        .font(.system(size: 23))
                        .foregroundStyle(Theme.ink)
                    let subtitle = [video.year, video.remarks].filter { !$0.isEmpty }.joined(separator: " · ")
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                    Button("加入文件夹") { showingFolderPicker = true }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.coral, in: RoundedRectangle(cornerRadius: 15))
                    if !favoriteFeedback.isEmpty {
                        Text(favoriteFeedback)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                    }
                    if isLoading {
                        ProgressView().tint(Theme.teal)
                    } else if !episodes.isEmpty {
                        Text("选择剧集（\(episodes.count)）")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 27) {
                            ForEach(episodes.indices, id: \.self) { index in
                                let episode = episodes[index]
                                Button { selectedEpisode = episode } label: {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Theme.ink)
                                        .frame(width: 54, height: 54)
                                        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 9))
                                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.7)))
                                }
                                .accessibilityLabel(episode.name)
                            }
                        }
                    } else {
                        Text(message)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedEpisode) { episode in
            PlayerScreen(video: video, episode: episode)
        }
        .confirmationDialog("加入文件夹", isPresented: $showingFolderPicker) {
            ForEach(store.folders) { folder in
                Button((store.contains(video, in: folder.id) ? "✓ " : "") + folder.name) {
                    store.add(video, to: folder.id)
                    favoriteFeedback = "已加入“" + folder.name + "”"
                }
            }
            Button("＋ 新建文件夹") {
                newFolderName = ""
                showingNewFolder = true
            }
        }
        .alert("新建文件夹", isPresented: $showingNewFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("创建") {
                if let folderID = store.createFolder(newFolderName) {
                    store.add(video, to: folderID)
                    favoriteFeedback = "已加入“" + newFolderName.trimmingCharacters(in: .whitespacesAndNewlines) + "”"
                }
            }
            Button("取消", role: .cancel) { }
        }
        .task {
            guard await DeviceManagement.shared.canUse() else {
                isLoading = false
                message = "此设备已被停用"
                return
            }
            guard UsageWindow.isActive() else {
                isLoading = false
                message = "网络不可用"
                return
            }
            do {
                episodes = try await VideoAPI.episodes(for: video)
                message = episodes.isEmpty ? "此片源没有可直接播放的地址，请尝试其他影片。" : ""
            } catch {
                message = "加载失败，请检查网络或片源"
            }
            isLoading = false
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: VideoStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingClear = false
    @State private var showingNewFolder = false
    @State private var folderName = ""

    var body: some View {
        ZStack {
            FrostedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Button("返回搜索") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.teal, in: RoundedRectangle(cornerRadius: 16))
                    HStack {
                        Text("我的收藏")
                            .font(.system(size: 23, weight: .bold))
                        Spacer()
                        if !store.folders.isEmpty {
                            if editing {
                                Button("全部删除") { confirmingClear = true }
                                    .foregroundStyle(Theme.muted)
                                Button("完成") { editing = false }
                            } else {
                                Button { editing = true } label: {
                                    Image(systemName: "trash").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("编辑收藏")
                            }
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    Button("＋ 新建文件夹") {
                        folderName = ""
                        showingNewFolder = true
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.teal, in: RoundedRectangle(cornerRadius: 15))

                    ForEach(store.folders) { folder in
                        HStack {
                            NavigationLink(destination: FolderView(folderID: folder.id)) {
                                Text(folder.name + "（\(folder.videos.count)）")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .disabled(editing)
                            if editing {
                                Button {
                                    store.deleteFolder(folder.id)
                                    if store.folders.isEmpty { editing = false }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13))
                                        .frame(width: 36, height: 44)
                                }
                                .accessibilityLabel("删除" + folder.name)
                            }
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("新建文件夹", isPresented: $showingNewFolder) {
            TextField("文件夹名称", text: $folderName)
            Button("创建") { _ = store.createFolder(folderName) }
            Button("取消", role: .cancel) { }
        }
        .confirmationDialog("删除全部文件夹和收藏的视频？", isPresented: $confirmingClear) {
            Button("全部删除", role: .destructive) {
                store.clearFolders()
                editing = false
            }
        }
    }
}

struct FolderView: View {
    let folderID: UUID
    @EnvironmentObject private var store: VideoStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingClear = false

    private var folder: FavoriteFolder? { store.folders.first { $0.id == folderID } }

    var body: some View {
        ZStack {
            FrostedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button("返回我的收藏") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.teal, in: RoundedRectangle(cornerRadius: 16))
                    if let folder {
                        HStack {
                            Text(folder.name)
                                .font(.system(size: 23, weight: .bold))
                            Spacer()
                            if !folder.videos.isEmpty {
                                if editing {
                                    Button("全部删除") { confirmingClear = true }
                                        .foregroundStyle(Theme.muted)
                                    Button("完成") { editing = false }
                                } else {
                                    Button { editing = true } label: {
                                        Image(systemName: "trash").frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("编辑收藏视频")
                                }
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        if folder.videos.isEmpty {
                            Text("还没有收藏的视频")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.muted)
                        }
                        ForEach(folder.videos) { video in
                            HStack {
                                NavigationLink(destination: DetailView(video: video, returnTitle: "返回收藏列表")) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(video.title).font(.system(size: 16, weight: .medium))
                                        if !video.details.isEmpty {
                                            Text(video.details)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .disabled(editing)
                                if editing {
                                    Button {
                                        store.remove(video, from: folderID)
                                        if store.folders.first(where: { $0.id == folderID })?.videos.isEmpty == true {
                                            editing = false
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 13))
                                            .frame(width: 36, height: 44)
                                    }
                                    .accessibilityLabel("删除" + video.title)
                                }
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("清空这个文件夹中的视频？", isPresented: $confirmingClear) {
            Button("清空", role: .destructive) {
                if let folder {
                    for video in folder.videos { store.remove(video, from: folderID) }
                }
                editing = false
            }
        }
    }
}

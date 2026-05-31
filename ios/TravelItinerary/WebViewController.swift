import UIKit

final class WebViewController: UIViewController {
    private enum Tab: Int {
        case itinerary
        case today
        case info
    }

    private let fileManager = FileManager.default
    private var config = TripConfig(trips: [])
    private var selectedTripId = ""
    private var tripData = TripData.empty
    private var itinerary = [ItineraryItem]()
    private var info = [InfoItem]()
    private var activeTab: Tab = .itinerary
    private var activeFilter = "all"
    private var activeDate = ""
    private var dateSectionViews = [String: UIView]()
    private weak var dateJumpScrollView: UIScrollView?
    private var dateChipViews = [String: UIView]()

    private lazy var headerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private lazy var controlsView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private lazy var controlsStack = UIStackView()
    private lazy var scrollView = UIScrollView()
    private lazy var stackView = UIStackView()
    private var controlsHeightConstraint: NSLayoutConstraint?

    private lazy var tripButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = Palette.text
        configuration.baseBackgroundColor = Palette.panelSoft
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)

        let button = UIButton(configuration: configuration)
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private lazy var tabControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["行程", "今日", "重要資訊"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = Palette.primary
        control.backgroundColor = Palette.panelSoft
        control.setTitleTextAttributes([
            .foregroundColor: Palette.muted,
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: Palette.primaryStrong,
            .font: UIFont.systemFont(ofSize: 14, weight: .black),
        ], for: .selected)
        control.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        return control
    }()

    private lazy var refreshButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "更新資料"
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = Palette.primary
        configuration.baseForegroundColor = Palette.primaryStrong
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)

        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(updateData), for: .touchUpInside)
        return button
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alpha = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .footnote)
        label.numberOfLines = 2
        label.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        return label
    }()

    private var cacheRootURL: URL {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TravelItinerary", isDirectory: true)
    }

    private var dataRootURL: URL {
        cacheRootURL.appendingPathComponent("data", isDirectory: true)
    }

    override func loadView() {
        let rootView = BackgroundView()

        headerView.translatesAutoresizingMaskIntoConstraints = false
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 44, right: 16)

        controlsStack.axis = .vertical
        controlsStack.spacing = 8
        controlsStack.isLayoutMarginsRelativeArrangement = true
        controlsStack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)

        let headerStack = UIStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .vertical
        headerStack.spacing = 10

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 10

        let icon = paddedLabel("✈️", font: .systemFont(ofSize: 18), background: Palette.panelSoft)
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 34).isActive = true
        icon.layer.cornerRadius = 12

        let title = UILabel()
        title.text = "旅遊行程"
        title.font = .systemFont(ofSize: 18, weight: .heavy)
        title.textColor = Palette.text

        titleRow.addArrangedSubview(icon)
        titleRow.addArrangedSubview(title)
        titleRow.addArrangedSubview(UIView())
        titleRow.addArrangedSubview(tripButton)

        headerStack.addArrangedSubview(titleRow)
        headerStack.addArrangedSubview(tabControl)

        headerView.contentView.addSubview(headerStack)
        controlsView.contentView.addSubview(controlsStack)
        scrollView.addSubview(stackView)
        rootView.addSubview(scrollView)
        rootView.addSubview(headerView)
        rootView.addSubview(controlsView)
        rootView.addSubview(refreshButton)
        rootView.addSubview(statusLabel)

        let controlsHeightConstraint = controlsView.heightAnchor.constraint(equalToConstant: 0)
        self.controlsHeightConstraint = controlsHeightConstraint

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            headerStack.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 10),
            headerStack.leadingAnchor.constraint(equalTo: headerView.contentView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerView.contentView.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: headerView.contentView.bottomAnchor, constant: -12),

            controlsView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            controlsView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            controlsStack.topAnchor.constraint(equalTo: controlsView.contentView.topAnchor),
            controlsStack.leadingAnchor.constraint(equalTo: controlsView.contentView.leadingAnchor),
            controlsStack.trailingAnchor.constraint(equalTo: controlsView.contentView.trailingAnchor),
            controlsStack.bottomAnchor.constraint(equalTo: controlsView.contentView.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: controlsView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            refreshButton.trailingAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            refreshButton.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            statusLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: refreshButton.topAnchor, constant: -12),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
        ])
        controlsHeightConstraint.isActive = true

        view = rootView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let backgroundView = view as? BackgroundView {
            backgroundView.updateLayout()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try prepareCachedData()
            try loadConfig()
            selectedTripId = initialTripId()
            try loadTrip(id: selectedTripId)
            render()
        } catch {
            renderError("無法載入行程資料")
        }
    }

    @objc private func tabChanged() {
        activeTab = Tab(rawValue: tabControl.selectedSegmentIndex) ?? .itinerary
        render(resetScroll: true)
    }

    @objc private func updateData() {
        guard let apiBaseURL else {
            showStatus("未設定 API 來源")
            return
        }

        setUpdating(true)
        Task {
            do {
                try await downloadLatestData(from: apiBaseURL)
                try await MainActor.run {
                    try loadConfig()
                    if !config.trips.contains(where: { $0.id == selectedTripId }) {
                        selectedTripId = config.trips.first?.id ?? ""
                        persistSelectedTrip(id: selectedTripId)
                    }
                    try loadTrip(id: selectedTripId)
                    render(resetScroll: true)
                    setUpdating(false)
                    showStatus("資料已更新，可離線使用")
                }
            } catch {
                await MainActor.run {
                    setUpdating(false)
                    showStatus("更新失敗，保留目前資料")
                }
            }
        }
    }

    private var apiBaseURL: URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: value)
        else {
            return nil
        }
        return url
    }

    private func prepareCachedData() throws {
        try fileManager.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)
        guard let bundledDataURL = Bundle.main.url(forResource: "data", withExtension: nil, subdirectory: "WebApp") else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard fileManager.fileExists(atPath: dataRootURL.path) else {
            try fileManager.copyItem(at: bundledDataURL, to: dataRootURL)
            return
        }

        try mergeBundledTripsIfNeeded(from: bundledDataURL)
    }

    private func mergeBundledTripsIfNeeded(from bundledDataURL: URL) throws {
        let bundledConfigURL = bundledDataURL.appendingPathComponent("config.json")
        let cachedConfigURL = dataRootURL.appendingPathComponent("config.json")
        guard
            let bundledConfig = try JSONSerialization.jsonObject(with: Data(contentsOf: bundledConfigURL)) as? [String: Any],
            var cachedConfig = try JSONSerialization.jsonObject(with: Data(contentsOf: cachedConfigURL)) as? [String: Any],
            let bundledTrips = bundledConfig["trips"] as? [[String: Any]],
            var cachedTrips = cachedConfig["trips"] as? [[String: Any]]
        else {
            return
        }

        var cachedIds = Set(cachedTrips.compactMap { $0["id"] as? String })
        var didMerge = false

        for trip in bundledTrips {
            guard let id = trip["id"] as? String, !cachedIds.contains(id) else { continue }
            let sourceURL = bundledDataURL.appendingPathComponent(id, isDirectory: true)
            let targetURL = dataRootURL.appendingPathComponent(id, isDirectory: true)
            if fileManager.fileExists(atPath: sourceURL.path), !fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.copyItem(at: sourceURL, to: targetURL)
            }
            cachedTrips.append(trip)
            cachedIds.insert(id)
            didMerge = true
        }

        guard didMerge else { return }
        cachedConfig["trips"] = cachedTrips
        let data = try JSONSerialization.data(withJSONObject: cachedConfig, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: cachedConfigURL, options: .atomic)
    }

    private func loadConfig() throws {
        config = try decode(TripConfig.self, from: dataRootURL.appendingPathComponent("config.json"))
        rebuildTripMenu()
    }

    private func loadTrip(id: String) throws {
        guard !id.isEmpty else { return }
        let tripURL = dataRootURL.appendingPathComponent(id, isDirectory: true)
        tripData = try decode(TripData.self, from: tripURL.appendingPathComponent("trip.json"))
        itinerary = try decode([ItineraryItem].self, from: tripURL.appendingPathComponent("itinerary.json"))
        info = try decode([InfoItem].self, from: tripURL.appendingPathComponent("info.json"))
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func rebuildTripMenu() {
        let previews = sortedTripPreviews()
        let selectedName = previews.first(where: { $0.option.id == selectedTripId })?.buttonTitle ?? config.trips.first?.name ?? "選擇旅程"
        tripButton.configuration?.title = selectedName

        let sections: [(TripTiming, String)] = [
            (.active, "旅途中"),
            (.upcoming, "即將出發"),
            (.completed, "旅行紀錄"),
            (.unscheduled, "未排定"),
        ]

        let menus = sections.compactMap { timing, title -> UIMenu? in
            let actions = previews
                .filter { $0.timing == timing }
                .map { preview in
                    UIAction(title: preview.menuTitle, state: preview.option.id == selectedTripId ? .on : .off) { [weak self] _ in
                        guard let self else { return }
                        do {
                            self.selectedTripId = preview.option.id
                            self.persistSelectedTrip(id: preview.option.id)
                            self.activeFilter = "all"
                            self.activeDate = ""
                            try self.loadTrip(id: preview.option.id)
                            self.render(resetScroll: true)
                        } catch {
                            self.renderError("無法載入 \(preview.option.name)")
                        }
                    }
                }
            guard !actions.isEmpty else { return nil }
            return UIMenu(title: title, options: .displayInline, children: actions)
        }

        tripButton.menu = UIMenu(children: menus)
    }

    private func initialTripId() -> String {
        let persisted = UserDefaults.standard.string(forKey: "selectedTripId") ?? ""
        if config.trips.contains(where: { $0.id == persisted }) {
            return persisted
        }
        return sortedTripPreviews().first?.option.id ?? config.trips.first?.id ?? ""
    }

    private func persistSelectedTrip(id: String) {
        UserDefaults.standard.set(id, forKey: "selectedTripId")
    }

    private func sortedTripPreviews() -> [TripPreview] {
        config.trips
            .map(tripPreview)
            .sorted { lhs, rhs in
                if lhs.timing.sortRank != rhs.timing.sortRank {
                    return lhs.timing.sortRank < rhs.timing.sortRank
                }
                switch lhs.timing {
                case .completed:
                    return lhs.sortDate > rhs.sortDate
                default:
                    return lhs.sortDate < rhs.sortDate
                }
            }
    }

    private func tripPreview(_ option: TripOption) -> TripPreview {
        let tripURL = dataRootURL.appendingPathComponent(option.id, isDirectory: true).appendingPathComponent("trip.json")
        let data = try? decode(TripData.self, from: tripURL)
        let dateRange = data?.dateRange ?? DateRange(start: "", end: "")
        let timing = tripTiming(for: dateRange)
        let rangeText = [formatDate(dateRange.start), formatDate(dateRange.end)]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        let title = rangeText.isEmpty ? option.name : "\(option.name) · \(rangeText)"
        return TripPreview(
            option: option,
            timing: timing,
            menuTitle: title,
            buttonTitle: option.name,
            sortDate: dateRange.start.ifEmpty(dateRange.end)
        )
    }

    private func downloadLatestData(from baseURL: URL) async throws {
        let configData = try await fetchData(from: baseURL.appendingPathComponent("data/config.json"))
        let tripIds = try JSONDecoder().decode(TripConfig.self, from: configData).trips.map(\.id)
        var downloads = [("config.json", configData)]

        for tripId in tripIds {
            for filename in ["itinerary.json", "info.json", "trip.json"] {
                let path = "\(tripId)/\(filename)"
                let data = try await fetchData(from: baseURL.appendingPathComponent("data/\(path)"))
                downloads.append((path, data))
            }
        }

        try fileManager.createDirectory(at: dataRootURL, withIntermediateDirectories: true)
        for (relativePath, data) in downloads {
            let targetURL = dataRootURL.appendingPathComponent(relativePath)
            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: targetURL, options: .atomic)
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func render(resetScroll: Bool = true) {
        rebuildTripMenu()
        renderControls()
        clearStack()
        if resetScroll {
            scrollView.setContentOffset(.zero, animated: false)
        }

        stackView.addArrangedSubview(overviewCard())
        switch activeTab {
        case .itinerary:
            renderItinerary()
        case .today:
            renderToday()
        case .info:
            renderInfo()
        }

        if !resetScroll {
            view.layoutIfNeeded()
            let maxOffset = max(scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom, -scrollView.adjustedContentInset.top)
            let y = min(max(scrollView.contentOffset.y, -scrollView.adjustedContentInset.top), maxOffset)
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: false)
        }
    }

    private func renderControls() {
        clearControls()
        dateJumpScrollView = nil
        dateChipViews.removeAll()

        guard activeTab == .itinerary else {
            controlsView.isHidden = true
            controlsHeightConstraint?.isActive = true
            return
        }

        controlsView.isHidden = false
        controlsHeightConstraint?.isActive = false

        let filtered = filteredItinerary()
        let dates = Array(Set(filtered.map(\.date).filter { !$0.isEmpty })).sorted()
        if activeDate.isEmpty || !dates.contains(activeDate) {
            activeDate = dates.first ?? ""
        }

        controlsStack.addArrangedSubview(filterBarView())
        if !dates.isEmpty {
            controlsStack.addArrangedSubview(dateJumpView(dates: dates))
        }
    }

    private func renderItinerary() {
        let filtered = filteredItinerary()
        let grouped = Dictionary(grouping: filtered, by: \.date)
        let dates = grouped.keys.sorted()
        dateSectionViews.removeAll()

        if !dates.isEmpty {
            if activeDate.isEmpty || !dates.contains(activeDate) {
                activeDate = dates.first ?? ""
            }
        }

        for (index, date) in dates.enumerated() {
            let items = grouped[date, default: []].sorted { $0.time < $1.time }
            let section = UIStackView()
            section.axis = .vertical
            section.spacing = 10

            section.addArrangedSubview(ticketDayHeader(day: index + 1, date: date, theme: items.first?.theme ?? "自由行程"))

            items.forEach { section.addArrangedSubview(ticketCard($0)) }
            dateSectionViews[date] = section
            stackView.addArrangedSubview(section)
        }

        if filtered.isEmpty {
            stackView.addArrangedSubview(emptyCard(title: "沒有符合的行程", subtitle: "請切換分類或更新資料"))
        }
    }

    private func renderToday() {
        let today = todayString()
        let items = itinerary.filter { $0.date == today }.sorted { $0.time < $1.time }
        let status = tripStatus()

        if items.isEmpty {
            let next = itinerary.sorted { $0.date == $1.date ? $0.time < $1.time : $0.date < $1.date }.first { $0.date >= today }
            let message: String
            if today < tripData.dateRange.start {
                message = "旅程尚未開始"
            } else if today > tripData.dateRange.end {
                message = "旅程已結束"
            } else {
                message = "今天沒有排定行程"
            }

            stackView.addArrangedSubview(heroCard(kicker: status.label, title: message, subtitle: "\(formatDate(tripData.dateRange.start)) → \(formatDate(tripData.dateRange.end))"))
            if let quickActions = quickActionsView() {
                stackView.addArrangedSubview(quickActions)
            }
            if let next {
                stackView.addArrangedSubview(sectionTitle("下一個行程"))
                stackView.addArrangedSubview(itemCard(next))
            }
            return
        }

        stackView.addArrangedSubview(heroCard(kicker: "今日行程", title: "\(formatShortDate(today)) \(weekday(today))", subtitle: "\(items.count) 項安排"))
        if let quickActions = quickActionsView() {
            stackView.addArrangedSubview(quickActions)
        }
        items.forEach { stackView.addArrangedSubview(itemCard($0)) }
    }

    private func renderInfo() {
        if let quickActions = quickActionsView() {
            stackView.addArrangedSubview(quickActions)
        }

        let grouped = Dictionary(grouping: info, by: \.category)
        for category in grouped.keys.sorted() {
            stackView.addArrangedSubview(sectionTitle(category.isEmpty ? "重要資訊" : category))
            grouped[category, default: []].forEach { stackView.addArrangedSubview(infoCard($0)) }
        }

        if info.isEmpty {
            stackView.addArrangedSubview(emptyCard(title: "尚未同步重要資訊", subtitle: "Notion 重要資訊資料庫目前沒有可顯示的資料"))
        }
    }

    private func overviewCard() -> UIView {
        let status = tripStatus()
        let card = baseCard()
        let stack = cardStack(in: card, spacing: 12)

        let flights = sortedFlights()
        let outbound = flights.first { flightDirection($0) == "outbound" } ?? flights.first
        let inbound = flights.first { flightDirection($0) == "inbound" } ?? flights.last
        let route = outbound.map { "\(airportCode($0.departure) ?? "TPE")  →  \(airportCode($0.arrival) ?? "CTS")" } ?? "TRIP"
        stack.addArrangedSubview(label(route, font: .systemFont(ofSize: 15, weight: .black), color: Palette.primary))
        stack.addArrangedSubview(label(formatContent(tripData.title), font: .systemFont(ofSize: 27, weight: .black), color: Palette.text))
        stack.addArrangedSubview(label("\(formatDate(tripData.dateRange.start)) - \(formatDate(tripData.dateRange.end)) · \(status.label)", font: .systemFont(ofSize: 14, weight: .semibold), color: Palette.muted))

        let stats = UIStackView()
        stats.axis = .horizontal
        stats.distribution = .fillEqually
        stats.spacing = 8
        stats.addArrangedSubview(statBox(title: "Days", value: "\(tripDays())"))
        stats.addArrangedSubview(statBox(title: "Plans", value: "\(itinerary.count)"))
        stats.addArrangedSubview(statBox(title: "Mode", value: tripData.vehicle.type.isEmpty ? "Trip" : tripData.vehicle.type))
        stack.addArrangedSubview(stats)

        let panels = [
            ("Regions", tripData.regions.isEmpty ? "未設定" : tripData.regions.joined(separator: " / ")),
            ("Next", nextItem().map { "\($0.date) \($0.time) · \(formatContent($0.title))" } ?? "尚未排定"),
            ("Vehicle", vehicleSummary()),
            ("Return", inbound.map { "\($0.date) · \($0.departure) → \($0.arrival)" } ?? "未設定"),
        ]

        for row in panels.chunked(into: 2) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually
            row.forEach { rowStack.addArrangedSubview(consolePanel(title: $0.0, value: $0.1)) }
            if row.count == 1 {
                rowStack.addArrangedSubview(UIView())
            }
            stack.addArrangedSubview(rowStack)
        }

        if !flights.isEmpty {
            let flightsStack = UIStackView()
            flightsStack.axis = .vertical
            flightsStack.spacing = 8
            flights.forEach { flightsStack.addArrangedSubview(flightSummaryCard($0)) }
            stack.addArrangedSubview(flightsStack)
        }

        return card
    }

    private func dateJumpView(dates: [String]) -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        dateJumpScrollView = scroll

        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 8
        scroll.addSubview(row)

        for (index, date) in dates.enumerated() {
            let chip = dateChip(day: index + 1, date: date, isActive: date == activeDate)
            chip.addAction(UIAction { [weak self] _ in
                self?.scrollToDate(date)
            }, for: .touchUpInside)
            dateChipViews[date] = chip
            row.addArrangedSubview(chip)
        }

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 70),
        ])

        return scroll
    }

    private func filterBarView() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true

        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 8
        scroll.addSubview(row)

        filterCategories().forEach { category in
            let button = filterChip(title: category == "all" ? "全部" : category, isActive: category == activeFilter)
            button.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.activeFilter = category
                self.activeDate = ""
                self.render(resetScroll: false)
            }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 42),
        ])

        return scroll
    }

    private func filterChip(title: String, isActive: Bool) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = isActive ? Palette.primary : Palette.panelSoft
        configuration.baseForegroundColor = isActive ? Palette.primaryStrong : Palette.text
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .black)
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 1
        button.layer.borderColor = (isActive ? Palette.primary : Palette.border).cgColor
        return button
    }

    private func dateChip(day: Int, date: String, isActive: Bool) -> UIControl {
        let control = LayoutActionControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.backgroundColor = isActive ? UIColor.clear : Palette.panelSoft
        control.layer.cornerRadius = 15
        control.layer.borderWidth = 1
        control.layer.borderColor = (isActive ? UIColor.clear : Palette.border).cgColor
        control.clipsToBounds = true

        if isActive {
            let gradient = CAGradientLayer()
            gradient.colors = [
                Palette.primary.withAlphaComponent(0.92).cgColor,
                Palette.accent.withAlphaComponent(0.82).cgColor,
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            control.layer.insertSublayer(gradient, at: 0)
            control.layoutAction = { view in
                gradient.frame = view.bounds
            }
        }

        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 9
        row.isUserInteractionEnabled = false

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let dayLabel = label("DAY \(String(day).leftPadded(to: 2))", font: .systemFont(ofSize: 10, weight: .black), color: isActive ? Palette.primaryStrong.withAlphaComponent(0.72) : Palette.muted)
        dayLabel.numberOfLines = 1
        let dateLabel = label(formatShortDate(date), font: .monospacedDigitSystemFont(ofSize: 17, weight: .black), color: isActive ? Palette.primaryStrong : Palette.text)
        dateLabel.numberOfLines = 1
        textStack.addArrangedSubview(dayLabel)
        textStack.addArrangedSubview(dateLabel)

        let weekdayLabel = paddedLabel(weekdaySymbol(date), font: .systemFont(ofSize: 12, weight: .black), background: isActive ? Palette.primaryStrong.withAlphaComponent(0.16) : Palette.primary.withAlphaComponent(0.92))
        weekdayLabel.textAlignment = .center
        weekdayLabel.textColor = isActive ? Palette.primaryStrong : Palette.primaryStrong
        weekdayLabel.layer.cornerRadius = 10
        weekdayLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true
        weekdayLabel.heightAnchor.constraint(equalToConstant: 28).isActive = true

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(weekdayLabel)
        control.addSubview(row)

        NSLayoutConstraint.activate([
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 98),
            row.topAnchor.constraint(equalTo: control.topAnchor, constant: 9),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -10),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -9),
        ])

        return control
    }

    private func scrollToDate(_ date: String) {
        activeDate = date
        refreshDateJump()
        view.layoutIfNeeded()
        scrollActiveDateChip(animated: false)

        guard let target = dateSectionViews[date] else { return }
        let topInset = scrollView.adjustedContentInset.top
        let maxOffset = max(scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom, 0)
        let targetY = max(min(target.frame.minY - topInset - 10, maxOffset), -topInset)
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
    }

    private func refreshDateJump() {
        UIView.performWithoutAnimation {
            self.renderControls()
            view.layoutIfNeeded()
        }
    }

    private func scrollActiveDateChip(animated: Bool) {
        guard
            let scroll = dateJumpScrollView,
            let chip = dateChipViews[activeDate]
        else {
            return
        }

        let chipFrame = chip.convert(chip.bounds, to: scroll)
        let targetRect = chipFrame.insetBy(dx: -18, dy: 0)
        scroll.scrollRectToVisible(targetRect, animated: animated)
    }

    private func itemCard(_ item: ItineraryItem) -> UIView {
        let card = baseCard()
        card.layer.shadowOpacity = 0.78
        let stack = cardStack(in: card, spacing: 9)

        let top = UIStackView()
        top.axis = .horizontal
        top.alignment = .top
        top.spacing = 10

        let time = label(item.time.isEmpty ? "--:--" : item.time, font: .monospacedDigitSystemFont(ofSize: 16, weight: .heavy), color: Palette.primary)
        time.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let main = UIStackView()
        main.axis = .vertical
        main.spacing = 5
        main.addArrangedSubview(categoryLabel(item.category))
        main.addArrangedSubview(label(formatContent(item.title), font: .systemFont(ofSize: 17, weight: .heavy), color: Palette.text))
        if !item.location.isEmpty {
            main.addArrangedSubview(label("📍 \(formatContent(item.location))", font: .systemFont(ofSize: 13, weight: .semibold), color: Palette.muted))
        }

        top.addArrangedSubview(time)
        top.addArrangedSubview(main)

        if let mapsURL = URL(string: item.mapsUrl), !item.mapsUrl.isEmpty {
            let button = smallButton("MAP")
            button.addAction(UIAction { _ in UIApplication.shared.open(mapsURL) }, for: .touchUpInside)
            top.addArrangedSubview(button)
        }

        stack.addArrangedSubview(top)

        let details = [item.transport, costText(item.estimatedCost), item.notes].filter { !$0.isEmpty }.map(formatContent)
        if !details.isEmpty {
            stack.addArrangedSubview(label(details.joined(separator: "\n"), font: .systemFont(ofSize: 13, weight: .regular), color: Palette.muted))
        }

        return card
    }

    private func ticketDayHeader(day: Int, date: String, theme: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12

        let dateBox = UIView()
        dateBox.backgroundColor = Palette.panelSoft
        dateBox.layer.cornerRadius = 18
        dateBox.layer.borderWidth = 1
        dateBox.layer.borderColor = Palette.border.cgColor

        let dateStack = UIStackView()
        dateStack.translatesAutoresizingMaskIntoConstraints = false
        dateStack.axis = .horizontal
        dateStack.spacing = 9
        dateStack.alignment = .center

        let dayLabel = label("DAY \(String(day).leftPadded(to: 2))", font: .systemFont(ofSize: 10, weight: .black), color: Palette.muted)
        dayLabel.numberOfLines = 1
        let dateLabel = label(formatShortDate(date), font: .monospacedDigitSystemFont(ofSize: 21, weight: .black), color: Palette.text)
        dateLabel.numberOfLines = 1
        let weekdayLabel = label(weekdaySymbol(date), font: .systemFont(ofSize: 12, weight: .black), color: Palette.accent)
        weekdayLabel.textAlignment = .right
        weekdayLabel.numberOfLines = 1

        dateStack.addArrangedSubview(dayLabel)
        dateStack.addArrangedSubview(dateLabel)
        dateStack.addArrangedSubview(weekdayLabel)
        dateBox.addSubview(dateStack)

        NSLayoutConstraint.activate([
            dateBox.widthAnchor.constraint(equalToConstant: 132),
            dateStack.topAnchor.constraint(equalTo: dateBox.topAnchor, constant: 11),
            dateStack.leadingAnchor.constraint(equalTo: dateBox.leadingAnchor, constant: 10),
            dateStack.trailingAnchor.constraint(equalTo: dateBox.trailingAnchor, constant: -10),
            dateStack.bottomAnchor.constraint(equalTo: dateBox.bottomAnchor, constant: -11),
        ])

        let themeLabel = label(formatContent(theme), font: .systemFont(ofSize: 15, weight: .black), color: Palette.text)
        row.addArrangedSubview(dateBox)
        row.addArrangedSubview(themeLabel)
        return row
    }

    private func ticketCard(_ item: ItineraryItem) -> UIView {
        let card = baseCard()
        let color = categoryColor(item.category)
        card.layer.borderColor = color.withAlphaComponent(0.42).cgColor
        card.backgroundColor = Palette.panelSoft
        card.clipsToBounds = true

        let wash = UIView()
        wash.translatesAutoresizingMaskIntoConstraints = false
        wash.backgroundColor = color.withAlphaComponent(0.10)
        card.insertSubview(wash, at: 0)
        NSLayoutConstraint.activate([
            wash.topAnchor.constraint(equalTo: card.topAnchor),
            wash.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            wash.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            wash.widthAnchor.constraint(equalToConstant: 108),
        ])

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 0
        stack.alignment = .fill
        card.addSubview(stack)

        let time = label(item.time.isEmpty ? "--:--" : item.time, font: .monospacedDigitSystemFont(ofSize: 16, weight: .black), color: color)
        time.textAlignment = .center
        time.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let divider = DashedDividerView(color: Palette.border.withAlphaComponent(0.82))
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        let main = UIStackView()
        main.axis = .vertical
        main.spacing = 6
        main.layoutMargins = UIEdgeInsets(top: 13, left: 12, bottom: 13, right: 10)
        main.isLayoutMarginsRelativeArrangement = true
        main.addArrangedSubview(ticketCategoryLabel(item.category, color: color))
        main.addArrangedSubview(label(formatContent(item.title), font: .systemFont(ofSize: 16, weight: .black), color: Palette.text))

        let details = [
            item.location.isEmpty ? "" : "LOC · \(item.location)",
            item.transport.isEmpty ? "" : "MOVE · \(item.transport)",
            item.estimatedCost > 0 ? "COST · ¥\(item.estimatedCost)" : "",
            item.notes.isEmpty ? "" : "NOTE · \(item.notes)",
        ]
        .filter { !$0.isEmpty }
        .map(formatContent)

        if !details.isEmpty {
            main.addArrangedSubview(label(details.joined(separator: "\n"), font: .systemFont(ofSize: 12, weight: .bold), color: Palette.muted))
        }

        stack.addArrangedSubview(time)
        stack.addArrangedSubview(divider)
        stack.addArrangedSubview(main)

        if let mapsURL = URL(string: item.mapsUrl), !item.mapsUrl.isEmpty {
            let button = ticketMapButton()
            button.addAction(UIAction { _ in UIApplication.shared.open(mapsURL) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 98),
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    private func infoCard(_ item: InfoItem) -> UIView {
        let card = baseCard()
        let stack = cardStack(in: card, spacing: 8)
        stack.addArrangedSubview(label(formatContent(item.name), font: .systemFont(ofSize: 17, weight: .heavy), color: Palette.text))

        [
            ("內容", item.content),
            ("地址", item.address),
            ("備註", item.notes),
        ].forEach { key, value in
            if !value.isEmpty {
                stack.addArrangedSubview(detailLine(title: key, value: formatContent(value)))
            }
        }

        if !item.phone.isEmpty {
            stack.addArrangedSubview(actionRow(title: "電話", value: item.phone, actionTitle: "撥打") {
                self.openPhone(item.phone)
            })
        }

        if !item.link.isEmpty, let url = URL(string: item.link) {
            stack.addArrangedSubview(actionRow(title: "連結", value: item.link, actionTitle: "查看") {
                UIApplication.shared.open(url)
            })
        }

        return card
    }

    private func heroCard(kicker: String, title: String, subtitle: String) -> UIView {
        let card = baseCard()
        card.backgroundColor = Palette.panelStrong
        let stack = cardStack(in: card, spacing: 7)
        stack.addArrangedSubview(label(kicker, font: .systemFont(ofSize: 13, weight: .bold), color: Palette.muted))
        stack.addArrangedSubview(label(title, font: .systemFont(ofSize: 25, weight: .black), color: Palette.text))
        stack.addArrangedSubview(label(subtitle, font: .systemFont(ofSize: 14, weight: .semibold), color: Palette.muted))
        return card
    }

    private func sectionTitle(_ text: String) -> UILabel {
        label(text, font: .systemFont(ofSize: 18, weight: .black), color: Palette.text)
    }

    private func emptyCard(title: String, subtitle: String) -> UIView {
        let card = baseCard()
        let stack = cardStack(in: card, spacing: 6)
        stack.addArrangedSubview(label(title, font: .systemFont(ofSize: 18, weight: .heavy), color: Palette.text))
        stack.addArrangedSubview(label(subtitle, font: .systemFont(ofSize: 14, weight: .semibold), color: Palette.muted))
        return card
    }

    private func baseCard() -> UIView {
        let view = UIView()
        view.backgroundColor = Palette.panel
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = Palette.border.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.42
        view.layer.shadowRadius = 20
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }

    private func cardStack(in card: UIView, spacing: CGFloat) -> UIStackView {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = spacing
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return stack
    }

    private func statBox(title: String, value: String) -> UIView {
        let view = UIView()
        view.backgroundColor = Palette.panelSoft
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = Palette.border.withAlphaComponent(0.7).cgColor

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.addArrangedSubview(label(title, font: .systemFont(ofSize: 11, weight: .bold), color: Palette.muted))
        stack.addArrangedSubview(label(value, font: .systemFont(ofSize: 16, weight: .black), color: Palette.text))
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])

        return view
    }

    private func detailLine(title: String, value: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.addArrangedSubview(label(title, font: .systemFont(ofSize: 11, weight: .heavy), color: Palette.muted))
        stack.addArrangedSubview(label(value, font: .systemFont(ofSize: 14, weight: .semibold), color: Palette.text))
        return stack
    }

    private func actionRow(title: String, value: String, actionTitle: String, action: @escaping () -> Void) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(label(title, font: .systemFont(ofSize: 11, weight: .heavy), color: Palette.muted))
        textStack.addArrangedSubview(label(formatContent(value), font: .systemFont(ofSize: 14, weight: .semibold), color: Palette.text))

        let button = smallButton(actionTitle)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(button)
        return row
    }

    private func consolePanel(title: String, value: String) -> UIView {
        let view = UIView()
        view.backgroundColor = Palette.panelSoft
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = Palette.border.cgColor

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 5
        stack.addArrangedSubview(label(title, font: .systemFont(ofSize: 11, weight: .black), color: Palette.muted))
        stack.addArrangedSubview(label(formatContent(value), font: .systemFont(ofSize: 13, weight: .heavy), color: Palette.text))
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])

        return view
    }

    private func flightSummaryCard(_ flight: Flight) -> UIView {
        let view = UIView()
        view.backgroundColor = Palette.panelSoft
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = Palette.border.cgColor

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6

        let labelText = flightDirection(flight) == "inbound" ? "RETURN" : "OUTBOUND"
        stack.addArrangedSubview(label(labelText, font: .systemFont(ofSize: 11, weight: .black), color: Palette.accent))
        stack.addArrangedSubview(label(formatContent(flight.airline.isEmpty ? flight.flightNumber : flight.airline), font: .systemFont(ofSize: 15, weight: .black), color: Palette.text))

        if !flight.ticketInfo.isEmpty {
            stack.addArrangedSubview(label(formatContent(flight.ticketInfo), font: .systemFont(ofSize: 12, weight: .semibold), color: Palette.muted))
        }

        stack.addArrangedSubview(label(formatContent("\(flight.departure.isEmpty ? "未定" : flight.departure)  →  \(flight.arrival.isEmpty ? "未定" : flight.arrival)"), font: .systemFont(ofSize: 14, weight: .heavy), color: Palette.text))
        stack.addArrangedSubview(label(formatContent("\(formatDate(flight.date)) · \(flight.type)"), font: .systemFont(ofSize: 12, weight: .semibold), color: Palette.muted))

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])

        return view
    }

    private func categoryLabel(_ text: String) -> UILabel {
        let label = paddedLabel(text.isEmpty ? "行程" : text, font: .systemFont(ofSize: 12, weight: .black), background: Palette.panelSoft)
        let color = categoryColor(text)
        label.textColor = color
        label.layer.cornerRadius = 9
        label.layer.borderWidth = 1
        label.layer.borderColor = color.withAlphaComponent(0.52).cgColor
        return label
    }

    private func ticketCategoryLabel(_ text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text.isEmpty ? "行程" : text
        label.font = .systemFont(ofSize: 11, weight: .black)
        label.textColor = color
        label.numberOfLines = 1
        return label
    }

    private func quickActionsView() -> UIView? {
        var actions = [(String, String, (() -> Void)?)]()
        if !tripData.vehicle.phone.isEmpty {
            let phone = tripData.vehicle.phone
            actions.append(("租車電話", phone, { [weak self] in self?.openPhone(phone) }))
        }
        if !tripData.vehicle.rentalCode.isEmpty {
            actions.append(("租車代號", tripData.vehicle.rentalCode, nil))
        }
        if !tripData.vehicle.notes.isEmpty {
            actions.append(("提醒", tripData.vehicle.notes, nil))
        }

        guard !actions.isEmpty else { return nil }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        for action in actions {
            stack.addArrangedSubview(quickActionCard(title: action.0, value: action.1, action: action.2))
        }

        return stack
    }

    private func quickActionCard(title: String, value: String, action: (() -> Void)?) -> UIView {
        let card = baseCard()
        card.backgroundColor = Palette.panelSoft
        let stack = cardStack(in: card, spacing: 5)

        let top = UIStackView()
        top.axis = .horizontal
        top.alignment = .center
        top.spacing = 10

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.addArrangedSubview(label(title, font: .systemFont(ofSize: 11, weight: .black), color: Palette.muted))
        textStack.addArrangedSubview(label(formatContent(value), font: .systemFont(ofSize: 14, weight: .heavy), color: Palette.text))

        top.addArrangedSubview(textStack)
        if let action {
            let button = smallButton("撥打")
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            top.addArrangedSubview(button)
        }
        stack.addArrangedSubview(top)

        return card
    }

    private func smallButton(_ title: String) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = Palette.primaryStrong
        configuration.baseBackgroundColor = Palette.primary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        return UIButton(configuration: configuration)
    }

    private func ticketMapButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("MAP", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .black)
        button.setTitleColor(Palette.primaryStrong, for: .normal)
        button.backgroundColor = Palette.primary
        button.widthAnchor.constraint(equalToConstant: 54).isActive = true
        return button
    }

    private func label(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func paddedLabel(_ text: String, font: UIFont, background: UIColor) -> UILabel {
        let label = InsetLabel()
        label.text = text
        label.font = font
        label.textAlignment = .center
        label.backgroundColor = background
        label.clipsToBounds = true
        label.insets = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        return label
    }

    private func renderError(_ message: String) {
        clearStack()
        stackView.addArrangedSubview(emptyCard(title: message, subtitle: "請確認 App 內建資料或網路更新來源"))
    }

    private func clearStack() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func clearControls() {
        controlsStack.arrangedSubviews.forEach {
            controlsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func setUpdating(_ updating: Bool) {
        refreshButton.isEnabled = !updating
        refreshButton.configuration?.title = updating ? "更新中..." : "更新資料"
    }

    private func showStatus(_ message: String) {
        statusLabel.text = "  \(message)  "
        UIView.animate(withDuration: 0.2) {
            self.statusLabel.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            UIView.animate(withDuration: 0.2) {
                self.statusLabel.alpha = 0
            }
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func weekday(_ date: String) -> String {
        guard let parsed = parseDate(date) else { return "" }
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let index = Calendar(identifier: .gregorian).component(.weekday, from: parsed) - 1
        return "(\(symbols[index]))"
    }

    private func weekdaySymbol(_ date: String) -> String {
        weekday(date).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func formatShortDate(_ value: String) -> String {
        String(value.dropFirst(5))
    }

    private func formatDate(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: "/")
    }

    private func tripDays() -> Int {
        guard let start = parseDate(tripData.dateRange.start), let end = parseDate(tripData.dateRange.end) else { return 0 }
        return (Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    private func tripStatus() -> (label: String, short: String) {
        switch tripTiming(for: tripData.dateRange) {
        case .active:
            return ("旅途中", "進行中")
        case .upcoming:
            return ("即將出發", "未開始")
        case .completed:
            return ("旅行紀錄", "完成")
        case .unscheduled:
            return ("尚未排定", "未排定")
        }
    }

    private func tripTiming(for dateRange: DateRange) -> TripTiming {
        guard !dateRange.start.isEmpty, !dateRange.end.isEmpty else { return .unscheduled }
        let today = todayString()
        if today < dateRange.start { return .upcoming }
        if today > dateRange.end { return .completed }
        return .active
    }

    private func airportCode(_ value: String) -> String? {
        value.components(separatedBy: " ").first { token in
            token.count == 3 && token.allSatisfy { $0.isUppercase }
        }
    }

    private func costText(_ value: Int) -> String {
        value > 0 ? "¥\(value)" : ""
    }

    private func categoryColor(_ category: String) -> UIColor {
        switch category {
        case "✈️ 航班":
            return UIColor(red: 0.39, green: 0.58, blue: 1.00, alpha: 1)
        case "🏨 住宿":
            return UIColor(red: 0.66, green: 0.45, blue: 1.00, alpha: 1)
        case "⛷️ 滑雪":
            return UIColor(red: 1.00, green: 0.36, blue: 0.68, alpha: 1)
        case "📍 景點":
            return UIColor(red: 0.26, green: 0.84, blue: 0.60, alpha: 1)
        case "🍜 餐廳":
            return UIColor(red: 1.00, green: 0.53, blue: 0.25, alpha: 1)
        case "🚗 交通", "🅿️ 露營車停車":
            return Palette.accent
        case "⚠️ 注意事項":
            return UIColor(red: 1.00, green: 0.38, blue: 0.34, alpha: 1)
        default:
            return Palette.primary
        }
    }

    private func openPhone(_ phone: String) {
        let cleaned = phone.filter { $0.isNumber || $0 == "+" || $0 == "-" }
        guard let url = URL(string: "tel:\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }

    private func formatContent(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\\s*｜\\s*", with: "\n", options: .regularExpression)
            .replacingOccurrences(
                of: "([^\\s])\\s*(?=(?:訂位代號|機票號碼|機型|航班編號|出發|抵達)：)",
                with: "$1\n",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "([^\\s])\\s*(?=(?:\\d+[.、]|[①②③④⑤⑥⑦⑧⑨⑩]))",
                with: "$1\n",
                options: .regularExpression
            )
    }

    private func filteredItinerary() -> [ItineraryItem] {
        guard activeFilter != "all" else { return itinerary }
        return itinerary.filter { $0.category == activeFilter }
    }

    private func filterCategories() -> [String] {
        let preferred = [
            "✈️ 航班",
            "🏨 住宿",
            "⛷️ 滑雪",
            "📍 景點",
            "🍜 餐廳",
            "🚗 交通",
            "🅿️ 露營車停車",
            "⚠️ 注意事項",
        ]
        let used = Set(itinerary.map(\.category).filter { !$0.isEmpty })
        let ordered = preferred.filter { used.contains($0) }
        let extra = used.subtracting(ordered).sorted()
        return ["all"] + ordered + extra
    }

    private func sortedFlights() -> [Flight] {
        tripData.flights.sorted { lhs, rhs in
            let rank = ["outbound": 0, "unknown": 1, "inbound": 2]
            let lhsRank = rank[flightDirection(lhs)] ?? 1
            let rhsRank = rank[flightDirection(rhs)] ?? 1
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.date < rhs.date
        }
    }

    private func flightDirection(_ flight: Flight) -> String {
        if !flight.direction.isEmpty {
            return flight.direction
        }

        let text = "\(flight.type) \(flight.departure) \(flight.arrival)".lowercased()
        if text.contains("回程") || text.contains("return") || text.contains("inbound") {
            return "inbound"
        }
        if text.contains("去程") || text.contains("outbound") {
            return "outbound"
        }
        if flight.departure.hasPrefix("TPE") {
            return "outbound"
        }
        if flight.arrival.hasPrefix("TPE") {
            return "inbound"
        }
        return "unknown"
    }

    private func nextItem() -> ItineraryItem? {
        let today = todayString()
        let sorted = itinerary.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.time < rhs.time : lhs.date < rhs.date
        }
        return sorted.first { $0.date >= today } ?? sorted.first
    }

    private func vehicleSummary() -> String {
        [
            tripData.vehicle.rentalCode,
            tripData.vehicle.company,
            tripData.vehicle.phone,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
        .ifEmpty("未設定")
    }
}

private enum Palette {
    static let primary = UIColor(red: 0.45, green: 0.88, blue: 0.92, alpha: 1)
    static let accent = UIColor(red: 1.00, green: 0.71, blue: 0.36, alpha: 1)
    static let primaryStrong = UIColor(red: 0.02, green: 0.10, blue: 0.14, alpha: 1)
    static let backgroundTop = UIColor(red: 0.04, green: 0.10, blue: 0.13, alpha: 1)
    static let backgroundBottom = UIColor(red: 0.04, green: 0.09, blue: 0.09, alpha: 1)
    static let panel = UIColor(red: 0.06, green: 0.12, blue: 0.15, alpha: 0.94)
    static let panelStrong = UIColor(red: 0.07, green: 0.15, blue: 0.19, alpha: 0.97)
    static let panelSoft = UIColor(red: 0.08, green: 0.16, blue: 0.20, alpha: 0.92)
    static let border = UIColor(red: 0.62, green: 0.87, blue: 0.89, alpha: 0.32)
    static let text = UIColor(red: 0.91, green: 0.97, blue: 0.97, alpha: 1)
    static let muted = UIColor(red: 0.62, green: 0.75, blue: 0.78, alpha: 1)
}

private final class BackgroundView: UIView {
    private let baseGradient = CAGradientLayer()
    private let diagonalWash = CAGradientLayer()
    private let vignette = CAGradientLayer()
    private let cyanGlow = RadialGradientLayer()
    private let amberGlow = RadialGradientLayer()
    private let lowerCyanGlow = RadialGradientLayer()
    private let gridLayer = CAShapeLayer()
    private let diagonalLinesLayer = CAShapeLayer()
    private let horizonLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true

        baseGradient.colors = [
            Palette.backgroundTop.cgColor,
            UIColor(red: 0.03, green: 0.07, blue: 0.09, alpha: 1).cgColor,
            Palette.backgroundBottom.cgColor,
        ]
        baseGradient.locations = [0, 0.48, 1]
        layer.addSublayer(baseGradient)

        diagonalWash.colors = [
            UIColor.white.withAlphaComponent(0.00).cgColor,
            Palette.primary.withAlphaComponent(0.12).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
            Palette.accent.withAlphaComponent(0.07).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
        ]
        diagonalWash.locations = [0, 0.20, 0.44, 0.70, 1]
        diagonalWash.startPoint = CGPoint(x: 0.05, y: 0.05)
        diagonalWash.endPoint = CGPoint(x: 0.95, y: 0.92)
        layer.addSublayer(diagonalWash)

        cyanGlow.colors = [
            UIColor(red: 0.34, green: 0.78, blue: 0.83, alpha: 0.42).cgColor,
            UIColor(red: 0.34, green: 0.78, blue: 0.83, alpha: 0.14).cgColor,
            UIColor(red: 0.34, green: 0.78, blue: 0.83, alpha: 0.0).cgColor,
        ]
        cyanGlow.locations = [0, 0.42, 1]
        layer.addSublayer(cyanGlow)

        amberGlow.colors = [
            Palette.accent.withAlphaComponent(0.28).cgColor,
            Palette.accent.withAlphaComponent(0.08).cgColor,
            Palette.accent.withAlphaComponent(0.0).cgColor,
        ]
        amberGlow.locations = [0, 0.46, 1]
        layer.addSublayer(amberGlow)

        lowerCyanGlow.colors = [
            UIColor(red: 0.12, green: 0.58, blue: 0.66, alpha: 0.24).cgColor,
            UIColor(red: 0.12, green: 0.58, blue: 0.66, alpha: 0.00).cgColor,
        ]
        layer.addSublayer(lowerCyanGlow)

        gridLayer.strokeColor = Palette.primary.withAlphaComponent(0.11).cgColor
        gridLayer.lineWidth = 1
        gridLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(gridLayer)

        diagonalLinesLayer.strokeColor = UIColor.white.cgColor
        diagonalLinesLayer.fillColor = UIColor.clear.cgColor
        diagonalLinesLayer.lineWidth = 1.4
        diagonalLinesLayer.lineCap = .round
        diagonalLinesLayer.opacity = 0.88
        layer.addSublayer(diagonalLinesLayer)

        horizonLayer.strokeColor = Palette.primary.withAlphaComponent(0.28).cgColor
        horizonLayer.fillColor = UIColor(red: 0.02, green: 0.07, blue: 0.08, alpha: 0.74).cgColor
        horizonLayer.lineWidth = 1.2
        layer.addSublayer(horizonLayer)

        vignette.colors = [
            UIColor.black.withAlphaComponent(0.08).cgColor,
            UIColor.black.withAlphaComponent(0.00).cgColor,
            UIColor.black.withAlphaComponent(0.36).cgColor,
        ]
        vignette.locations = [0, 0.48, 1]
        vignette.startPoint = CGPoint(x: 0.5, y: 0)
        vignette.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(vignette)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLayout() {
        baseGradient.frame = bounds
        diagonalWash.frame = bounds
        cyanGlow.frame = CGRect(x: -bounds.width * 0.34, y: -bounds.height * 0.12, width: bounds.width * 1.12, height: bounds.width * 1.12)
        amberGlow.frame = CGRect(x: bounds.width * 0.48, y: bounds.height * 0.02, width: bounds.width * 0.72, height: bounds.width * 0.72)
        lowerCyanGlow.frame = CGRect(x: bounds.width * 0.10, y: bounds.height * 0.54, width: bounds.width * 0.95, height: bounds.width * 0.78)
        gridLayer.frame = bounds
        gridLayer.path = gridPath(in: bounds).cgPath
        diagonalLinesLayer.frame = bounds
        diagonalLinesLayer.path = diagonalLinesPath(in: bounds).cgPath
        horizonLayer.frame = bounds
        horizonLayer.path = horizonPath(in: bounds).cgPath
        vignette.frame = bounds
    }

    private func gridPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let step: CGFloat = 42
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += step
        }
        return path
    }

    private func diagonalLinesPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let lower = rect.height * 0.74
        addDiagonalLine(to: path, start: CGPoint(x: -rect.width * 0.10, y: lower), end: CGPoint(x: rect.width * 0.72, y: lower - rect.width * 0.30))
        addDiagonalLine(to: path, start: CGPoint(x: rect.width * 0.18, y: lower + 42), end: CGPoint(x: rect.width * 1.10, y: lower - rect.width * 0.24))
        addDiagonalLine(to: path, start: CGPoint(x: rect.width * 0.58, y: rect.height * 0.28), end: CGPoint(x: rect.width * 1.05, y: rect.height * 0.12))
        return path
    }

    private func addDiagonalLine(to path: UIBezierPath, start: CGPoint, end: CGPoint) {
        path.move(to: start)
        path.addLine(to: end)
    }

    private func horizonPath(in rect: CGRect) -> UIBezierPath {
        let baseY = rect.height * 0.88
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: baseY))
        path.addLine(to: CGPoint(x: rect.width * 0.10, y: baseY - 20))
        path.addLine(to: CGPoint(x: rect.width * 0.21, y: baseY - 8))
        path.addLine(to: CGPoint(x: rect.width * 0.31, y: baseY - 42))
        path.addLine(to: CGPoint(x: rect.width * 0.45, y: baseY - 16))
        path.addLine(to: CGPoint(x: rect.width * 0.58, y: baseY - 54))
        path.addLine(to: CGPoint(x: rect.width * 0.74, y: baseY - 22))
        path.addLine(to: CGPoint(x: rect.width * 0.86, y: baseY - 38))
        path.addLine(to: CGPoint(x: rect.width, y: baseY - 14))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.close()
        return path
    }
}

private final class RadialGradientLayer: CAGradientLayer {
    override init() {
        super.init()
        type = .radial
        startPoint = CGPoint(x: 0.5, y: 0.5)
        endPoint = CGPoint(x: 1, y: 1)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class LayoutActionControl: UIControl {
    var layoutAction: ((UIView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutAction?(self)
    }
}

private final class DashedDividerView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let color: UIColor

    init(color: UIColor) {
        self.color = color
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.lineWidth = 1
        shapeLayer.lineDashPattern = [4, 5]
        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.midX, y: 0))
        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
        shapeLayer.frame = bounds
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color.cgColor
    }
}

private final class InsetLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

private struct TripConfig: Decodable {
    var trips: [TripOption]
}

private struct TripOption: Decodable {
    let id: String
    let name: String
}

private enum TripTiming {
    case active
    case upcoming
    case completed
    case unscheduled

    var sortRank: Int {
        switch self {
        case .active:
            return 0
        case .upcoming:
            return 1
        case .completed:
            return 2
        case .unscheduled:
            return 3
        }
    }
}

private struct TripPreview {
    let option: TripOption
    let timing: TripTiming
    let menuTitle: String
    let buttonTitle: String
    let sortDate: String
}

private struct TripData: Decodable {
    let title: String
    let dateRange: DateRange
    let regions: [String]
    let flights: [Flight]
    let vehicle: Vehicle

    static let empty = TripData(title: "", dateRange: DateRange(start: "", end: ""), regions: [], flights: [], vehicle: Vehicle())

    private enum CodingKeys: String, CodingKey {
        case title
        case dateRange
        case regions
        case flights
        case vehicle
    }

    init(title: String, dateRange: DateRange, regions: [String], flights: [Flight], vehicle: Vehicle) {
        self.title = title
        self.dateRange = dateRange
        self.regions = regions
        self.flights = flights
        self.vehicle = vehicle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.decodeString(.title)
        dateRange = (try? container.decodeIfPresent(DateRange.self, forKey: .dateRange)) ?? DateRange(start: "", end: "")
        regions = (try? container.decodeIfPresent([String].self, forKey: .regions)) ?? []
        flights = (try? container.decodeIfPresent([Flight].self, forKey: .flights)) ?? []
        vehicle = (try? container.decodeIfPresent(Vehicle.self, forKey: .vehicle)) ?? Vehicle()
    }
}

private struct DateRange: Decodable {
    let start: String
    let end: String

    private enum CodingKeys: String, CodingKey {
        case start
        case end
    }

    init(start: String, end: String) {
        self.start = start
        self.end = end
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = container.decodeString(.start)
        end = container.decodeString(.end)
    }
}

private struct Flight: Decodable {
    var type = ""
    var direction = ""
    var airline = ""
    var flightNumber = ""
    var ticketInfo = ""
    var date = ""
    var departure = ""
    var arrival = ""
    var aircraft = ""
    var bookingCode = ""
    var ticketNumber = ""
    var link = ""
    var notes = ""

    private enum CodingKeys: String, CodingKey {
        case type
        case direction
        case airline
        case flightNumber
        case ticketInfo
        case date
        case departure
        case arrival
        case aircraft
        case bookingCode
        case ticketNumber
        case link
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeString(.type)
        direction = container.decodeString(.direction)
        airline = container.decodeString(.airline)
        flightNumber = container.decodeString(.flightNumber)
        ticketInfo = container.decodeString(.ticketInfo)
        date = container.decodeString(.date)
        departure = container.decodeString(.departure)
        arrival = container.decodeString(.arrival)
        aircraft = container.decodeString(.aircraft)
        bookingCode = container.decodeString(.bookingCode)
        ticketNumber = container.decodeString(.ticketNumber)
        link = container.decodeString(.link)
        notes = container.decodeString(.notes)
    }
}

private struct Vehicle: Decodable {
    var type = ""
    var company = ""
    var phone = ""
    var rentalCode = ""
    var pickupDate = ""
    var pickupTime = ""
    var returnDate = ""
    var returnTime = ""
    var notes = ""

    private enum CodingKeys: String, CodingKey {
        case type
        case company
        case phone
        case rentalCode
        case pickupDate
        case pickupTime
        case returnDate
        case returnTime
        case notes
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decodeString(.type)
        company = container.decodeString(.company)
        phone = container.decodeString(.phone)
        rentalCode = container.decodeString(.rentalCode)
        pickupDate = container.decodeString(.pickupDate)
        pickupTime = container.decodeString(.pickupTime)
        returnDate = container.decodeString(.returnDate)
        returnTime = container.decodeString(.returnTime)
        notes = container.decodeString(.notes)
    }
}

private struct ItineraryItem: Decodable {
    var date = ""
    var theme = ""
    var time = ""
    var category = ""
    var title = ""
    var location = ""
    var mapsUrl = ""
    var transport = ""
    var estimatedCost = 0
    var notes = ""

    private enum CodingKeys: String, CodingKey {
        case date
        case theme
        case time
        case category
        case title
        case location
        case mapsUrl
        case transport
        case estimatedCost
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = container.decodeString(.date)
        theme = container.decodeString(.theme)
        time = container.decodeString(.time)
        category = container.decodeString(.category)
        title = container.decodeString(.title)
        location = container.decodeString(.location)
        mapsUrl = container.decodeString(.mapsUrl)
        transport = container.decodeString(.transport)
        estimatedCost = container.decodeInt(.estimatedCost)
        notes = container.decodeString(.notes)
    }
}

private struct InfoItem: Decodable {
    var category = ""
    var name = ""
    var content = ""
    var phone = ""
    var address = ""
    var notes = ""
    var link = ""

    private enum CodingKeys: String, CodingKey {
        case category
        case name
        case content
        case phone
        case address
        case notes
        case link
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = container.decodeString(.category)
        name = container.decodeString(.name)
        content = container.decodeString(.content)
        phone = container.decodeString(.phone)
        address = container.decodeString(.address)
        notes = container.decodeString(.notes)
        link = container.decodeString(.link)
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        let padding = max(0, length - count)
        return String(repeating: "0", count: padding) + self
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private extension KeyedDecodingContainer {
    func decodeString(_ key: Key) -> String {
        (try? decodeIfPresent(String.self, forKey: key)) ?? ""
    }

    func decodeInt(_ key: Key) -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return 0
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var chunks = [[Element]]()
        var index = 0
        while index < count {
            chunks.append(Array(self[index..<Swift.min(index + size, count)]))
            index += size
        }
        return chunks
    }
}

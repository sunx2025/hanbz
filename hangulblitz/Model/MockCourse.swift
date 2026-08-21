//
//  MockCourse.swift
//  hangulblitz
//
//  Temporary UI data. Course configuration loading will replace this file.
//

import Foundation

enum MockCourse {
    static let levelOneID = "level-1"

    static func course(locale: Locale) -> Course {
        let usesSimplifiedChinese = locale.language.languageCode?.identifier == "zh"
        let content = usesSimplifiedChinese ? chineseContent : englishContent

        return Course(
            id: "hangul-foundations",
            levels: content.enumerated().map { index, copy in
                let levelNumber = index + 1
                let practice = practiceContent(levelNumber: levelNumber)

                return Level(
                    id: "level-\(levelNumber)",
                    number: levelNumber,
                    title: copy.title,
                    description: copy.description,
                    overview: Overview(),
                    currentActivities: activities(
                        levelNumber: levelNumber,
                        scope: .current,
                        content: practice.current,
                        locale: locale
                    ),
                    mixedActivities: activities(
                        levelNumber: levelNumber,
                        scope: .mixed,
                        content: practice.mixed,
                        locale: locale
                    )
                )
            }
        )
    }

    private struct PracticeContent {
        let guided: [[String]]?
        let reading: [[String]]?
        let listening: [[String]]?
        let contrasts: [[String]]
    }

    private struct LevelPracticeContent {
        let current: PracticeContent?
        let mixed: PracticeContent?
    }

    private static func activities(
        levelNumber: Int,
        scope: PracticeScope,
        content: PracticeContent?,
        locale: Locale
    ) -> [LearningActivity] {
        guard let content else { return [] }

        return [
            content.guided.map {
                activity(
                    levelNumber: levelNumber,
                    scope: scope,
                    kind: .guided,
                    itemSections: $0,
                    contrasts: [],
                    locale: locale
                )
            },
            content.reading.map {
                activity(
                    levelNumber: levelNumber,
                    scope: scope,
                    kind: .reading,
                    itemSections: $0,
                    contrasts: [],
                    locale: locale
                )
            },
            content.listening.map {
                activity(
                    levelNumber: levelNumber,
                    scope: scope,
                    kind: .listening,
                    itemSections: $0,
                    contrasts: content.contrasts,
                    locale: locale
                )
            }
        ].compactMap { $0 }
    }

    private static func activity(
        levelNumber: Int,
        scope: PracticeScope,
        kind: ActivityKind,
        itemSections: [[String]],
        contrasts: [[String]],
        locale: Locale
    ) -> LearningActivity {
        let copy = activityCopy(scope: scope, kind: kind)

        return LearningActivity(
            id: "level-\(levelNumber)-\(copy.idSuffix)",
            kind: kind,
            scope: scope,
            title: String(localized: copy.titleKey, defaultValue: copy.title, locale: locale),
            description: String(
                localized: copy.descriptionKey,
                defaultValue: copy.description,
                locale: locale
            ),
            itemSections: itemSections,
            contrasts: contrasts
        )
    }

    private struct ActivityCopy {
        let idSuffix: String
        let titleKey: StaticString
        let title: String.LocalizationValue
        let descriptionKey: StaticString
        let description: String.LocalizationValue
    }

    private static func activityCopy(scope: PracticeScope, kind: ActivityKind) -> ActivityCopy {
        switch (scope, kind) {
        case (.current, .guided):
            ActivityCopy(
                idSuffix: "get-familiar",
                titleKey: "activity.get_familiar.title",
                title: "Get Familiar",
                descriptionKey: "activity.get_familiar.description",
                description: "Learn this level’s pattern"
            )
        case (.current, .reading):
            ActivityCopy(
                idSuffix: "reading",
                titleKey: "activity.reading.title",
                title: "Reading Practice",
                descriptionKey: "activity.reading.description",
                description: "Practise symbols introduced in this level"
            )
        case (.current, .listening):
            ActivityCopy(
                idSuffix: "listening",
                titleKey: "activity.listening.title",
                title: "Listening Practice",
                descriptionKey: "activity.listening.description",
                description: "Practise symbols introduced in this level"
            )
        case (.mixed, .guided):
            ActivityCopy(
                idSuffix: "connections",
                titleKey: "activity.connections.title",
                title: "Make Connections",
                descriptionKey: "activity.connections.description",
                description: "Link this level with earlier patterns"
            )
        case (.mixed, .reading):
            ActivityCopy(
                idSuffix: "mixed-reading",
                titleKey: "activity.mixed_reading.title",
                title: "Mixed Reading Practice",
                descriptionKey: "activity.mixed_reading.description",
                description: "Read mixed items up to this level"
            )
        case (.mixed, .listening):
            ActivityCopy(
                idSuffix: "mixed-listening",
                titleKey: "activity.mixed_listening.title",
                title: "Mixed Listening Practice",
                descriptionKey: "activity.mixed_listening.description",
                description: "Recognise mixed audio up to this level"
            )
        }
    }

    private static func practiceContent(levelNumber: Int) -> LevelPracticeContent {
        switch levelNumber {
        case 1:
            LevelPracticeContent(
                current: PracticeContent(
                    guided: [
                        ["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"],
                        ["아", "어", "오", "우", "으", "이"]
                    ],
                    reading: [
                        ["ㅏ", "ㅓ", "ㅗ", "ㅜ", "ㅡ", "ㅣ"],
                        ["아", "어", "오", "우", "으", "이"]
                    ],
                    listening: [["아", "어", "오", "우", "으", "이"]],
                    contrasts: [["아", "어"], ["오", "우"], ["우", "으"]]
                ),
                mixed: nil
            )
        case 2:
            LevelPracticeContent(
                current: PracticeContent(
                    guided: [
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"]
                    ],
                    reading: [
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"]
                    ],
                    listening: [
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"]
                    ],
                    contrasts: [
                        ["가", "나"], ["거", "너"], ["고", "노"],
                        ["구", "누"], ["그", "느"], ["기", "니"]
                    ]
                ),
                mixed: PracticeContent(
                    guided: [
                        ["아", "가", "나"], ["어", "거", "너"],
                        ["오", "고", "노"], ["우", "구", "누"],
                        ["으", "그", "느"], ["이", "기", "니"]
                    ],
                    reading: [
                        ["아", "어", "오", "우", "으", "이"],
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"]
                    ],
                    listening: [
                        ["아", "어", "오", "우", "으", "이"],
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"]
                    ],
                    contrasts: [
                        ["아", "가"], ["가", "나"], ["아", "나"],
                        ["어", "거"], ["거", "너"], ["어", "너"],
                        ["오", "고"], ["고", "노"], ["오", "노"],
                        ["우", "구"], ["구", "누"], ["우", "누"],
                        ["으", "그"], ["그", "느"], ["으", "느"],
                        ["이", "기"], ["기", "니"], ["이", "니"]
                    ]
                )
            )
        case 3:
            LevelPracticeContent(
                current: PracticeContent(
                    guided: [
                        ["다", "더", "도", "두", "드", "디"],
                        ["라", "러", "로", "루", "르", "리"],
                        ["다", "라", "더", "러"],
                        ["도", "로", "두", "루"],
                        ["드", "르", "디", "리"]
                    ],
                    reading: [
                        ["다", "더", "도", "두", "드", "디"],
                        ["라", "러", "로", "루", "르", "리"]
                    ],
                    listening: [
                        ["다", "더", "도", "두", "드", "디"],
                        ["라", "러", "로", "루", "르", "리"]
                    ],
                    contrasts: []
                ),
                mixed: PracticeContent(
                    guided: [
                        ["가", "나", "다", "라"], ["거", "너", "더", "러"],
                        ["고", "노", "도", "로"], ["구", "누", "두", "루"],
                        ["그", "느", "드", "르"], ["기", "니", "디", "리"]
                    ],
                    reading: [
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"],
                        ["다", "더", "도", "두", "드", "디"],
                        ["라", "러", "로", "루", "르", "리"]
                    ],
                    listening: [
                        ["가", "거", "고", "구", "그", "기"],
                        ["나", "너", "노", "누", "느", "니"],
                        ["다", "더", "도", "두", "드", "디"],
                        ["라", "러", "로", "루", "르", "리"]
                    ],
                    contrasts: []
                )
            )
        default:
            placeholderPracticeContent(levelNumber: levelNumber)
        }
    }

    // Levels 4–9 keep the UI populated until their activity-by-activity mock data is defined.
    private static func placeholderPracticeContent(levelNumber: Int) -> LevelPracticeContent {
        let sections = [placeholderItems(levelNumber: levelNumber)]
        let content = PracticeContent(
            guided: sections,
            reading: sections,
            listening: sections,
            contrasts: []
        )

        return LevelPracticeContent(current: content, mixed: content)
    }

    private static func placeholderItems(levelNumber: Int) -> [String] {
        switch levelNumber {
        case 4:
            ["ㅁ", "ㅂ", "마", "바", "머", "버", "모", "보", "무", "부"]
        case 5:
            ["가", "거", "고", "구", "그", "기", "나", "너", "노", "누"]
        case 6:
            ["ㅑ", "ㅕ", "ㅛ", "ㅠ", "야", "여", "요", "유"]
        case 7:
            ["가", "겨", "교", "규", "나", "녀", "뇨", "뉴"]
        case 8:
            ["ㅅ", "ㅈ", "ㅎ", "사", "자", "하", "서", "저", "허"]
        default:
            ["사", "서", "소", "수", "스", "시", "샤", "셔", "쇼", "슈"]
        }
    }

    private struct LevelCopy {
        let title: String
        let description: String
    }

    private static let englishContent = [
        LevelCopy(title: "Basic Vowels", description: "ㅏ ㅓ ㅗ ㅜ ㅡ ㅣ and silence initial ㅇ"),
        LevelCopy(title: "Basic Consonants ㄱ ㄴ", description: "ㄱ ㄴ and combinations"),
        LevelCopy(title: "Basic Consonants ㄷ ㄹ", description: "ㄷ ㄹ and combinations"),
        LevelCopy(title: "Basic Consonants ㅁ ㅂ", description: "ㅁ ㅂ and combinations"),
        LevelCopy(title: "Mixed Practice I", description: "가 거 고 구 그 기 etc"),
        LevelCopy(title: "Y Series Vowels ㅑ ㅕ ㅛ ㅠ", description: "ㅑ ㅕ ㅛ ㅠ"),
        LevelCopy(title: "Mixed Practice II", description: "가 겨 교 규 etc"),
        LevelCopy(title: "Basic Consonants ㅅ ㅈ ㅎ", description: "ㅅ ㅈ ㅎ and combinations"),
        LevelCopy(title: "Mixed Practice III", description: "사 서 소 수 스 시 샤 셔 쇼 슈 etc")
    ]

    private static let chineseContent = [
        LevelCopy(title: "基础元音", description: "ㅏ ㅓ ㅗ ㅜ ㅡ ㅣ及无声初声ㅇ"),
        LevelCopy(title: "基础辅音 ㄱ ㄴ", description: "ㄱ ㄴ及其拼读"),
        LevelCopy(title: "基础辅音 ㄷ ㄹ", description: "ㄷ ㄹ及其拼读"),
        LevelCopy(title: "基础辅音 ㅁ ㅂ", description: "ㅁ ㅂ及其拼读"),
        LevelCopy(title: "综合拼读（一）", description: "가 거 고 구 그 기等"),
        LevelCopy(title: "Y系列元音 ㅑ ㅕ ㅛ ㅠ", description: "ㅑ ㅕ ㅛ ㅠ"),
        LevelCopy(title: "综合拼读（二）", description: "가 겨 교 규等"),
        LevelCopy(title: "基础辅音 ㅅ ㅈ ㅎ", description: "ㅅ ㅈ ㅎ及其拼读"),
        LevelCopy(title: "综合拼读（三）", description: "사 서 소 수 스 시 샤 셔 쇼 슈等")
    ]
}

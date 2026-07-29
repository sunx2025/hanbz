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
                return Level(
                    id: "level-\(levelNumber)",
                    number: levelNumber,
                    title: copy.title,
                    description: copy.description,
                    overview: Overview(),
                    currentActivities: currentActivities(levelNumber: levelNumber, locale: locale),
                    mixedActivities: mixedActivities(levelNumber: levelNumber, locale: locale)
                )
            }
        )
    }

    private static func currentActivities(levelNumber: Int, locale: Locale) -> [LearningActivity] {
        [
            activity(
                id: "level-\(levelNumber)-get-familiar",
                kind: .guided,
                titleKey: "activity.get_familiar.title",
                title: "Get Familiar",
                descriptionKey: "activity.get_familiar.description",
                description: "Learn this level’s pattern",
                locale: locale
            ),
            activity(
                id: "level-\(levelNumber)-reading",
                kind: .reading,
                titleKey: "activity.reading.title",
                title: "Reading Practice",
                descriptionKey: "activity.reading.description",
                description: "Practise symbols introduced in this level",
                locale: locale
            ),
            activity(
                id: "level-\(levelNumber)-listening",
                kind: .listening,
                titleKey: "activity.listening.title",
                title: "Listening Practice",
                descriptionKey: "activity.listening.description",
                description: "Practise symbols introduced in this level",
                locale: locale
            )
        ]
    }

    private static func mixedActivities(levelNumber: Int, locale: Locale) -> [LearningActivity] {
        [
            activity(
                id: "level-\(levelNumber)-connections",
                kind: .guided,
                titleKey: "activity.connections.title",
                title: "Make Connections",
                descriptionKey: "activity.connections.description",
                description: "Link this level with earlier patterns",
                locale: locale
            ),
            activity(
                id: "level-\(levelNumber)-mixed-reading",
                kind: .reading,
                titleKey: "activity.mixed_reading.title",
                title: "Mixed Reading Practice",
                descriptionKey: "activity.mixed_reading.description",
                description: "Read mixed items up to this level",
                locale: locale
            ),
            activity(
                id: "level-\(levelNumber)-mixed-listening",
                kind: .listening,
                titleKey: "activity.mixed_listening.title",
                title: "Mixed Listening Practice",
                descriptionKey: "activity.mixed_listening.description",
                description: "Recognise mixed audio up to this level",
                locale: locale
            )
        ]
    }

    private static func activity(
        id: String,
        kind: ActivityKind,
        titleKey: StaticString,
        title: String.LocalizationValue,
        descriptionKey: StaticString,
        description: String.LocalizationValue,
        locale: Locale
    ) -> LearningActivity {
        LearningActivity(
            id: id,
            kind: kind,
            title: String(localized: titleKey, defaultValue: title, locale: locale),
            description: String(localized: descriptionKey, defaultValue: description, locale: locale),
            items: [],
            contrasts: []
        )
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

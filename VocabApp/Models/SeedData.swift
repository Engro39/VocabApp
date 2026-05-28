import Foundation

struct SeedData {
    struct SeedWord {
        let word: String
        let meaning: String
        let pronunciation: String
        let partOfSpeech: String
        let exampleEn: String
        let examples: [String]
        let detailedDefinition: String
        let nuance: String
        let relatedWords: [String]
        let set: Int
    }

    static let sampleSet: [SeedWord] = [
        SeedWord(
            word: "Embark",
            meaning: "착수하다, 시작하다",
            pronunciation: "/ɪmˈbɑːrk/",
            partOfSpeech: "verb",
            exampleEn: "Embark on a new journey.",
            examples: [
                "We will embark on our journey to Europe next month.",
                "The company is embarking on a new business venture.",
                "Passengers began to embark on the cruise ship at noon."
            ],
            detailedDefinition: "To begin a journey or voyage, especially by ship or aircraft. To start or commence on a new project, adventure, or undertaking.",
            nuance: "'Embark on/upon'은 새로운 프로젝트나 모험을 시작할 때 사용되며, 약간의 위엄함과 결단력이 담긴 표현입니다.",
            relatedWords: ["begin", "commence", "start", "board", "undertake", "launch", "venture"],
            set: 1
        ),
        SeedWord(
            word: "Full-fledged",
            meaning: "완전한, 어엿한",
            pronunciation: "/ˌfʊl ˈflɛdʒd/",
            partOfSpeech: "adjective",
            exampleEn: "He is a full-fledged adult.",
            examples: [
                "She is now a full-fledged member of the team.",
                "The company has grown into a full-fledged enterprise.",
                "He became a full-fledged doctor after completing his residency."
            ],
            detailedDefinition: "Completely developed, established, or qualified, having all the necessary qualifications or features.",
            nuance: "원래는 새가 날개 깃털을 모두 갖추었다는 뜻에서 유래했습니다.",
            relatedWords: ["complete", "fully developed", "mature", "established", "qualified"],
            set: 1
        ),
        SeedWord(
            word: "Scripture",
            meaning: "성경, 경전",
            pronunciation: "/ˈskrɪptʃər/",
            partOfSpeech: "noun",
            exampleEn: "According to scripture, we must love one another.",
            examples: [
                "She quoted a Scripture passage during her sermon.",
                "Many believers study Scripture daily for spiritual guidance.",
                "The Scriptures provide moral teachings for Christians."
            ],
            detailedDefinition: "Sacred writings or texts of a religion, especially the Bible in Christianity.",
            nuance: "보통 기독교 맥락에서 성경을 지칭하지만, 다른 종교의 경전을 표현할 때도 사용할 수 있습니다.",
            relatedWords: ["Bible", "sacred text", "holy book", "verse", "gospel", "religious text"],
            set: 1
        ),
        SeedWord(
            word: "Make yourself at home",
            meaning: "편하게 있어",
            pronunciation: "/meɪk jɔːrˈsɛlf ət hoʊm/",
            partOfSpeech: "phrase",
            exampleEn: "Come in, make yourself at home!",
            examples: [
                "Welcome to my apartment! Please, make yourself at home.",
                "Don't be shy - make yourself at home. Help yourself to anything in the fridge.",
                "When you visit us, we want you to make yourself at home."
            ],
            detailedDefinition: "A polite expression inviting someone to relax and feel comfortable in your space as if it were their own home.",
            nuance: "손님을 환영하고 편하게 해주려는 친절한 태도를 표현하며, 형식적이지 않은 상황에서 자주 사용됩니다.",
            relatedWords: ["feel at home", "welcome", "make someone comfortable", "put someone at ease"],
            set: 1
        ),
        SeedWord(
            word: "Cunning",
            meaning: "교활한, 약삭빠른",
            pronunciation: "/ˈkʌnɪŋ/",
            partOfSpeech: "adjective, noun",
            exampleEn: "The cunning fox outsmarted everyone.",
            examples: [
                "The cunning fox escaped the hunter's trap by taking an unexpected route.",
                "She used cunning tactics to win the negotiation without revealing her true intentions.",
                "His cunning allowed him to navigate the complex political situation successfully."
            ],
            detailedDefinition: "Skillful at achieving one's aims by deceit or evasion.",
            nuance: "긍정적으로는 '영리함', '기지'를 의미하지만 부정적으로는 '간교함', '사기성'을 내포할 수 있습니다.",
            relatedWords: ["clever", "sly", "shrewd", "crafty", "deceptive", "astute"],
            set: 1
        ),
        SeedWord(
            word: "Sulking",
            meaning: "삐치다, 토라지다",
            pronunciation: "/ˈsʌlkɪŋ/",
            partOfSpeech: "verb / noun",
            exampleEn: "Stop sulking and talk to me.",
            examples: [
                "She was sulking in her room after their argument.",
                "He's been sulking all day because he didn't get invited to the party.",
                "Stop sulking and tell me what's wrong."
            ],
            detailedDefinition: "To be silent, moody, and bad-tempered, usually because you are upset or annoyed about something.",
            nuance: "sulking은 아이들이 보이는 행동처럼 인식되는 경향이 있어 성인이 이 행동을 하면 다소 미성숙해 보일 수 있습니다.",
            relatedWords: ["pouting", "brooding", "moping", "being moody", "silent treatment"],
            set: 1
        ),
        SeedWord(
            word: "Stinking hag",
            meaning: "냄새나는 못된 마녀 할멈",
            pronunciation: "/ˈstɪŋkɪŋ hæg/",
            partOfSpeech: "phrase",
            exampleEn: "The stinking hag cackled in the darkness.",
            examples: [
                "He called her a stinking hag in a fit of rage.",
                "That stinking hag ruined everything with her lies.",
                "Don't be such a stinking hag about helping others."
            ],
            detailedDefinition: "A derogatory and offensive phrase combining 'stinking' with 'hag'. It is an insulting expression.",
            nuance: "이는 매우 모욕적이고 공격적인 욕설로, 여성혐오적 표현입니다. 현대에는 사용을 피해야 하며, 문학이나 역사적 맥락에서만 볼 수 있습니다.",
            relatedWords: ["hag", "witch", "beldam", "shrew", "insult"],
            set: 1
        ),
        SeedWord(
            word: "Supposed to",
            meaning: "~하기로 되어 있다",
            pronunciation: "/səˈpoʊzd tu/",
            partOfSpeech: "phrase",
            exampleEn: "You were supposed to call me!",
            examples: [
                "You are supposed to arrive at 9 AM.",
                "I was supposed to call him yesterday, but I forgot.",
                "Children are supposed to listen to their parents."
            ],
            detailedDefinition: "Indicates what is expected, required, or believed to be true based on plans, rules, or assumptions.",
            nuance: "'supposed to'는 실제로 일어나지 않은 일에도 사용되며, 예상/의도/규칙을 나타냅니다.",
            relatedWords: ["expected to", "required to", "ought to", "should"],
            set: 1
        ),
        SeedWord(
            word: "I guess so",
            meaning: "그런 것 같아, 뭐 그렇지",
            pronunciation: "/aɪ ɡɛs soʊ/",
            partOfSpeech: "phrase",
            exampleEn: "Are you tired? I guess so.",
            examples: [
                "A: Do you want to go to the party? B: I guess so.",
                "A: Is this the right way to the station? B: I guess so, but I'm not completely sure.",
                "A: Will you help me with this project? B: I guess so, if you really need me."
            ],
            detailedDefinition: "A somewhat uncertain or reluctant agreement or acknowledgment.",
            nuance: "'I guess so'는 긍정이지만 확신이 없거나 마지못해 동의할 때 사용된다.",
            relatedWords: ["I suppose so", "I think so", "sure, I guess", "okay, I guess", "probably"],
            set: 1
        ),
        SeedWord(
            word: "Sly",
            meaning: "교활한, 음흉한, 능글맞은",
            pronunciation: "/slaɪ/",
            partOfSpeech: "adjective",
            exampleEn: "He gave a sly smile and walked away.",
            examples: [
                "He gave me a sly smile, as if he knew my secret.",
                "She made a sly comment about his new haircut.",
                "The sly fox managed to steal the chicken without being noticed."
            ],
            detailedDefinition: "Cunning or wily in a subtle or playful way, given to or done with secrecy or stealth.",
            nuance: "'Sly'는 부정적인 속임수보다는 영리함이나 장난스러운 뉘앙스를 강조할 때가 많습니다.",
            relatedWords: ["cunning", "crafty", "sneaky", "wily", "devious"],
            set: 1
        ),
        SeedWord(
            word: "Impromptu",
            meaning: "즉흥적인, 즉석의",
            pronunciation: "/ɪmˈprɑːmptjuː/",
            partOfSpeech: "adjective, adverb, noun",
            exampleEn: "We threw an impromptu party last night.",
            examples: [
                "She gave an impromptu speech at the wedding without any notes.",
                "The band decided to have an impromptu jam session in the studio.",
                "He made an impromptu decision to travel to Paris last minute."
            ],
            detailedDefinition: "Done or made without advance preparation or planning, performed or spoken without rehearsal.",
            nuance: "'Impromptu'는 긍정적인 뉘앙스로 기발함과 창의성을 암시할 수 있지만, 부정적으로는 준비 부족을 의미할 수 있다.",
            relatedWords: ["spontaneous", "extemporaneous", "unrehearsed", "ad-lib", "spur-of-the-moment"],
            set: 1
        ),
        SeedWord(
            word: "Eccentric",
            meaning: "괴짜인, 별난, 독특한",
            pronunciation: "/ɪkˈsɛntrɪk/",
            partOfSpeech: "adjective, noun",
            exampleEn: "The eccentric professor wore a hat indoors.",
            examples: [
                "He has eccentric fashion sense and always wears mismatched clothes.",
                "The eccentric artist refused to follow any traditional rules in her paintings.",
                "Her eccentric personality made her stand out among her conventional colleagues."
            ],
            detailedDefinition: "Deviating from the center or from a circular form. Also describes a person or their behavior that is unconventional, strange, or markedly different from what is expected.",
            nuance: "긍정적 또는 중립적인 뉘앙스로 '개성 있는', '독특한'이라는 의미로 쓰일 수 있지만, 때로는 '이상하고 불가해한'이라는 부정적 뉘앙스도 포함할 수 있습니다.",
            relatedWords: ["quirky", "unconventional", "peculiar", "odd", "strange", "idiosyncratic"],
            set: 1
        ),
        SeedWord(
            word: "Speck of dust",
            meaning: "먼지 한 톨, 티끌",
            pronunciation: "/spɛk əv dʌst/",
            partOfSpeech: "phrase",
            exampleEn: "We are just a speck of dust in the universe.",
            examples: [
                "A speck of dust landed on her shoulder.",
                "In the vastness of space, Earth is just a speck of dust.",
                "He could see specks of dust floating in the sunlight."
            ],
            detailedDefinition: "A tiny particle of dust, so small it is almost invisible to the naked eye. Often used metaphorically to describe something insignificant.",
            nuance: "'speck'은 매우 작은 입자를 강조하며, 때로는 비유적으로 '무시할 수 있는 작은 존재'라는 의미로도 쓰인다.",
            relatedWords: ["particle", "grain", "dust mote", "speck", "fragment"],
            set: 1
        ),
        SeedWord(
            word: "Slob",
            meaning: "게으르고 지저분한 사람",
            pronunciation: "/slɑːb/",
            partOfSpeech: "noun",
            exampleEn: "Don't be a slob — clean your room.",
            examples: [
                "He's such a slob, his apartment is always filled with dirty dishes and clothes.",
                "Don't be a slob and clean up after yourself!",
                "She married a slob, but over the years he learned to keep the house tidy."
            ],
            detailedDefinition: "A person who is habitually messy, dirty, or lazy.",
            nuance: "부정적이고 조금 모욕적인 표현으로, 누군가를 직접 '슬롭'이라고 부르면 기분 나쁠 수 있습니다.",
            relatedWords: ["messy", "lazy", "slothful", "unkempt", "slovenly"],
            set: 1
        ),
        SeedWord(
            word: "Sturdy",
            meaning: "튼튼한, 견고한, 탄탄한",
            pronunciation: "/ˈstɜːrdi/",
            partOfSpeech: "adjective",
            exampleEn: "This is a very sturdy table.",
            examples: [
                "The sturdy wooden table has lasted for over 20 years.",
                "He has a sturdy build and looks very strong.",
                "This sturdy backpack is perfect for hiking trips."
            ],
            detailedDefinition: "Strong and solid in construction or build, capable of withstanding rough use or difficult conditions.",
            nuance: "긍정적인 뉘앙스로 물건이나 사람의 강함과 내구성을 강조한다.",
            relatedWords: ["strong", "durable", "robust", "solid", "firm"],
            set: 1
        ),
        SeedWord(
            word: "Faint",
            meaning: "희미한 / 기절하다",
            pronunciation: "/feɪnt/",
            partOfSpeech: "adjective, verb, noun",
            exampleEn: "She fainted from the heat.",
            examples: [
                "I heard a faint sound coming from the other room.",
                "She felt faint and had to sit down immediately.",
                "He fainted during the ceremony and had to be carried out."
            ],
            detailedDefinition: "Not clearly seen, heard, or smelled, barely perceptible. As a verb, to lose consciousness temporarily.",
            nuance: "'Faint'는 형용사로 쓸 때 '희미한, 약한' 의미로, 빛, 소리, 냄새 등이 거의 감지되지 않는 상태를 나타낸다.",
            relatedWords: ["dim", "weak", "feeble", "pass out", "dizzy", "faint-hearted"],
            set: 1
        ),
        SeedWord(
            word: "Parched",
            meaning: "바싹 마른, 몹시 목마른",
            pronunciation: "/pɑːrtʃt/",
            partOfSpeech: "adjective",
            exampleEn: "I'm absolutely parched. Can I have some water?",
            examples: [
                "After hiking in the desert all day, I felt completely parched.",
                "The parched soil cracked under the intense summer heat.",
                "Her parched lips needed moisturizer after the long flight."
            ],
            detailedDefinition: "Extremely dry, lacking moisture or water. It can describe land, lips, throat, or a person suffering from extreme thirst.",
            nuance: "'Parched'는 단순히 '건조한'을 넘어 극도로 건조하거나 갈증으로 고생하는 상태를 강조합니다.",
            relatedWords: ["dry", "thirsty", "desiccated", "arid"],
            set: 1
        ),
        SeedWord(
            word: "Lurk",
            meaning: "숨어서 기다리다, 도사리다",
            pronunciation: "/lɜːrk/",
            partOfSpeech: "verb",
            exampleEn: "Danger lurks around every corner.",
            examples: [
                "A predator was lurking in the dark alley.",
                "She lurked on the forum for months before posting her first comment.",
                "Danger lurks around every corner in that neighborhood."
            ],
            detailedDefinition: "To remain hidden or out of sight, often with the implication of waiting or observing.",
            nuance: "온라인 커뮤니티에서는 '즉시 참여하지 않고 구경하다'는 긍정적 의미도 있지만, 일반적으로는 숨어서 기다리는 불안감이나 위험한 상황을 암시한다.",
            relatedWords: ["hide", "conceal", "stalk", "observe", "linger"],
            set: 1
        ),
        SeedWord(
            word: "Extort",
            meaning: "갈취하다, 강탈하다",
            pronunciation: "/ɪkˈstɔːrt/",
            partOfSpeech: "verb",
            exampleEn: "He extorted money from the victim.",
            examples: [
                "The criminal gang extorted money from local business owners by threatening violence.",
                "He was arrested for attempting to extort funds from the company using confidential information.",
                "They extorted thousands of dollars from victims through blackmail."
            ],
            detailedDefinition: "To obtain something from someone by force, threats, or coercion, typically money or valuable items.",
            nuance: "'Extort'는 협박, 위협, 강압을 통해 재물을 빼앗는 불법 행위를 의미한다.",
            relatedWords: ["blackmail", "coerce", "threaten", "intimidate", "extortion"],
            set: 1
        ),
        SeedWord(
            word: "Exhort",
            meaning: "강력히 권고하다, 촉구하다",
            pronunciation: "/ɪɡˈzɔːrt/",
            partOfSpeech: "verb",
            exampleEn: "She exhorted her team to keep going.",
            examples: [
                "The coach exhorted his team to give their best effort in the final match.",
                "The activist exhorted the crowd to take action against climate change.",
                "She exhorted her friend to pursue his dreams despite the obstacles."
            ],
            detailedDefinition: "To strongly urge or persuade someone to do something, often with passion and earnestness.",
            nuance: "'Exhort'는 단순한 제안이 아니라 열정적이고 강력한 권고를 의미합니다.",
            relatedWords: ["urge", "encourage", "persuade", "implore", "beseech"],
            set: 1
        )
    ]
}

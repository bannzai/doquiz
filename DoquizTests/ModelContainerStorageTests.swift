import Testing
@testable import Doquiz

/// アプリの保存先をメモリ内にするかを、起動の引数から決める判定を確かめる。テストは開発用のビルド (DEBUG) で動く。
struct ModelContainerStorageTests {
    /// 起動の引数に `-uiTestInMemoryStore` がある時は、ほかの引数と並んでいてもメモリ内にすることを確かめる。
    @Test(arguments: [
        ["-uiTestInMemoryStore"],
        ["/path/to/Doquiz", "-uiTestInMemoryStore"],
        ["/path/to/Doquiz", "-AppleLanguages", "(ja)", "-uiTestInMemoryStore"],
    ])
    func 引数があるとメモリ内の保存先にする(launchArguments: [String]) {
        #expect(isModelContainerStoredInMemoryOnly(launchArguments: launchArguments))
    }

    /// 起動の引数が無い時と、似ているが違う引数 (大文字小文字が違う・前後に文字が付いている・先頭の `-` が無い) の時は、端末の保存先のままにすることを確かめる。
    @Test(arguments: [
        [],
        ["/path/to/Doquiz"],
        ["-uitestinmemorystore"],
        ["-uiTestInMemoryStoreX"],
        ["uiTestInMemoryStore"],
        ["-uiTestInMemoryStore=1"],
    ])
    func 引数が無いか違う引数では端末の保存先のままにする(launchArguments: [String]) {
        #expect(isModelContainerStoredInMemoryOnly(launchArguments: launchArguments) == false)
    }
}

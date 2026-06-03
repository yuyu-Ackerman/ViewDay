import XCTest
@testable import ViewDay

final class HomeLocationDisplayFormatterTests: XCTestCase {
    func testUsesSpecificAddressNameAndCityDistrictForChongqing() {
        let location = LocationSnapshot(
            name: "南岸区",
            city: "南岸区",
            district: "南岸区",
            address: "中国 重庆市 南岸区 崇文路 黄桷垭一带",
            latitude: nil,
            longitude: nil,
            isManuallyEdited: false
        )

        let text = HomeLocationDisplayFormatter.text(from: location)

        XCTAssertEqual(text.title, "黄桷垭")
        XCTAssertEqual(text.subtitle, "重庆市 · 南岸区")
    }

    func testUsesRoadNameAndKeepsCitySuffixForHangzhou() {
        let location = LocationSnapshot(
            name: "文二西路",
            city: "杭州市",
            district: "余杭区",
            address: "中国 浙江省 杭州市 余杭区 文二西路",
            latitude: nil,
            longitude: nil,
            isManuallyEdited: false
        )

        let text = HomeLocationDisplayFormatter.text(from: location)

        XCTAssertEqual(text.title, "文二西路")
        XCTAssertEqual(text.subtitle, "杭州市 · 余杭区")
    }
}

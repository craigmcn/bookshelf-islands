require "test_helper"

class LayoutAccessibilityTest < ActionDispatch::IntegrationTest
  test "html has a lang attribute" do
    get books_url
    assert_select "html[lang=en]"
  end

  test "has a skip-to-content link targeting the main landmark" do
    get books_url
    assert_select "a.visually-hidden-focusable[href='#main-content']", text: "Skip to content"
    assert_select "main#main-content"
  end

  test "navbar toggler has an accessible name and reflects the collapse target" do
    get books_url
    assert_select "button.navbar-toggler[aria-controls=navbarMain][aria-expanded=false][aria-label=?]", "Toggle navigation"
  end
end

require "test_helper"

class BankHolidayTest < ActiveSupport::TestCase
  test "dates returns sorted dates for the division" do
    BankHoliday.create!(division: "england-and-wales", date: Date.new(2026, 12, 25), title: "Christmas")
    BankHoliday.create!(division: "england-and-wales", date: Date.new(2026, 1, 1), title: "New Year")

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ], BankHoliday.dates
  end

  test "dates is scoped to the division" do
    BankHoliday.create!(division: "england-and-wales", date: Date.new(2026, 1, 1), title: "New Year")
    BankHoliday.create!(division: "scotland", date: Date.new(2026, 1, 2), title: "2 January")

    assert_equal [ Date.new(2026, 1, 1) ], BankHoliday.dates("england-and-wales")
    assert_equal [ Date.new(2026, 1, 2) ], BankHoliday.dates("scotland")
  end

  test "replace_division inserts the given dates" do
    BankHoliday.replace_division("england-and-wales", [ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ])

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ], BankHoliday.dates
  end

  test "replace_division is idempotent" do
    dates = [ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ]
    BankHoliday.replace_division("england-and-wales", dates)
    BankHoliday.replace_division("england-and-wales", dates)

    assert_equal 2, BankHoliday.where(division: "england-and-wales").count
    assert_equal dates, BankHoliday.dates
  end

  test "replace_division prunes dates no longer present" do
    BankHoliday.replace_division("england-and-wales", [ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ])
    BankHoliday.replace_division("england-and-wales", [ Date.new(2026, 12, 25) ])

    assert_equal [ Date.new(2026, 12, 25) ], BankHoliday.dates
  end

  test "replace_division leaves other divisions untouched" do
    BankHoliday.create!(division: "scotland", date: Date.new(2026, 1, 2), title: "2 January")
    BankHoliday.replace_division("england-and-wales", [ Date.new(2026, 1, 1) ])

    assert_equal [ Date.new(2026, 1, 2) ], BankHoliday.dates("scotland")
  end
end

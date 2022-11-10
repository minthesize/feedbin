require "test_helper"

module Search
  class SearchIndexRemoveTest < ActiveSupport::TestCase
    setup do
      clear_search
      @user = users(:new)
      @feeds = create_feeds(@user)
      @entries = @user.entries
    end

    test "should remove entries from search index" do
      assert_difference -> { $search[:main].with { _1.count(Entry.table_name) } }, -@entries.count do
        SearchIndexRemove.new.perform(@entries.map(&:id))
        $search[:main].with { _1.refresh }
      end
    end
  end
end
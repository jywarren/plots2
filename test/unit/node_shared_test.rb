require 'test_helper'

class NodeSharedTest < ActiveSupport::TestCase

  test "that NodeShared can be used to convert short codes like [notes:foo] into tables which list notes" do
    before = "Here are some notes in a table: \n\n[notes:test] \n\nThis is how you make it work:\n\n`[notes:tagname]`\n\nMake sense?"
    assert NodeShared.notes_grid(before)
puts NodeShared.notes_grid(before)
    assert_equal 1, NodeShared.notes_grid(before).scan('<table class="table inline-grid notes-grid notes-grid-test notes-grid-test-').length
    assert_equal 1, NodeShared.notes_grid(before).scan('<table').length
    assert_equal 3, NodeShared.notes_grid(before).scan('notes-grid-test').length
  end

  test "that NodeShared can be used to convert short codes like [activities:foo] into tables which list activity notes" do
    before = "Here are some activities in a table: \n\n[activities:test] \n\nThis is how you make it work:\n\n`[activities:tagname]`\n\nMake sense?"
    assert NodeShared.activities_grid(before)
    assert_equal 1, NodeShared.activities_grid(before).scan('<table class="table inline-grid activity-grid activity-grid-test activity-grid-test-').length
    assert_equal 1, NodeShared.activities_grid(before).scan('<table').length
    assert_equal 3, NodeShared.activities_grid(before).scan('activity-grid-test').length
  end

  test "that NodeShared can be used to convert short codes like [upgrades:foo] into tables which list upgrade notes" do
    before = "Here are some upgrades in a table: \n\n[upgrades:test] \n\nThis is how you make it work:\n\n`[upgrades:tagname]`\n\nMake sense?"
    assert NodeShared.upgrades_grid(before)
    assert_equal 1, NodeShared.upgrades_grid(before).scan('<table class="table inline-grid upgrades-grid upgrades-grid-test upgrades-grid-test-').length
    assert_equal 1, NodeShared.upgrades_grid(before).scan('<table').length
    assert_equal 3, NodeShared.upgrades_grid(before).scan('upgrades-grid-test').length
  end

end

Feature: Groups
  Background:
    Given I sign in as "John Doe"
    And "John Doe" is owner of group "Owned"
    And "John Doe" is guest of group "Guest"

  Scenario: I should have back to group button
    When I visit group "Owned" page
    Then I should see back to dashboard button

  @javascript
  Scenario: I should see group "Owned" dashboard list
    When I visit group "Owned" page
    Then I should see group "Owned" projects list
    And I should see projects activity feed

  Scenario: I should see group "Owned" issues list
    Given project from group "Owned" has issues assigned to me
    When I visit group "Owned" issues page
    Then I should see issues from group "Owned" assigned to me

  Scenario: I should see group "Owned" merge requests list
    Given project from group "Owned" has merge requests assigned to me
    When I visit group "Owned" merge requests page
    Then I should see merge requests from group "Owned" assigned to me

  @javascript
  Scenario: I should add user to projects in group "Owned"
    Given User "Mary Jane" exists
    When I visit group "Owned" members page
    And I select user "Mary Jane" from list with role "Reporter"
    Then I should see user "Mary Jane" in team list

  Scenario: I should see edit group "Owned" page
    When I visit group "Owned" settings page
    And I change group "Owned" name to "new-name"
    Then I should see new group "Owned" name

  Scenario: I edit group "Owned" avatar
    When I visit group "Owned" settings page
    And I change group "Owned" avatar
    And I visit group "Owned" settings page
    Then I should see new group "Owned" avatar
    And I should see the "Remove avatar" button

  Scenario: I remove group "Owned" avatar
    When I visit group "Owned" settings page
    And I have group "Owned" avatar
    And I visit group "Owned" settings page
    And I remove group "Owned" avatar
    Then I should not see group "Owned" avatar
    And I should not see the "Remove avatar" button

  @javascript
  Scenario: Add user to group
    Given gitlab user "Mike"
    When I visit group "Owned" members page
    And I click link "Add members"
    When I select "Mike" as "Reporter"
    Then I should see "Mike" in team list as "Reporter"

  @javascript
  Scenario: Invite user to group
    When I visit group "Owned" members page
    And I click link "Add members"
    When I select "sjobs@apple.com" as "Reporter"
    Then I should see "sjobs@apple.com" in team list as invited "Reporter"

  # Leave

  @javascript
  Scenario: Owner should be able to remove himself from group if he is not the last owner
    Given "Mary Jane" is owner of group "Owned"
    When I visit group "Owned" members page
    Then I should see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list
    When I click on the "Remove User From Group" button for "John Doe"
    And I visit group "Owned" members page
    Then I should not see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list

  @javascript
  Scenario: Owner should not be able to remove himself from group if he is the last owner
    Given "Mary Jane" is guest of group "Owned"
    When I visit group "Owned" members page
    Then I should see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list
    Then I should not see the "Remove User From Group" button for "John Doe"

  @javascript
  Scenario: Guest should be able to remove himself from group
    Given "Mary Jane" is guest of group "Guest"
    When I visit group "Guest" members page
    Then I should see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list
    When I click on the "Remove User From Group" button for "John Doe"
    When I visit group "Guest" members page
    Then I should not see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list

  @javascript
  Scenario: Guest should be able to remove himself from group even if he is the only user in the group
    When I visit group "Guest" members page
    Then I should see user "John Doe" in team list
    When I click on the "Remove User From Group" button for "John Doe"
    When I visit group "Guest" members page
    Then I should not see user "John Doe" in team list

  # Remove others

  Scenario: Owner should be able to remove other users from group
    Given "Mary Jane" is owner of group "Owned"
    When I visit group "Owned" members page
    Then I should see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list
    When I click on the "Remove User From Group" button for "Mary Jane"
    When I visit group "Owned" members page
    Then I should see user "John Doe" in team list
    Then I should not see user "Mary Jane" in team list

  Scenario: Guest should not be able to remove other users from group
    Given "Mary Jane" is guest of group "Guest"
    When I visit group "Guest" members page
    Then I should see user "John Doe" in team list
    Then I should see user "Mary Jane" in team list
    Then I should not see the "Remove User From Group" button for "Mary Jane"

  Scenario: Search member by name
    Given "Mary Jane" is guest of group "Guest"
    And I visit group "Guest" members page
    When I search for 'Mary' member
    Then I should see user "Mary Jane" in team list
    Then I should not see user "John Doe" in team list

  # Group milestones

  Scenario: I should see group "Owned" milestone index page with no milestones
    When I visit group "Owned" page
    And I click on group milestones
    Then I should see group milestones index page has no milestones

  Scenario: I should see group "Owned" milestone index page with milestones
    Given Group has projects with milestones
    When I visit group "Owned" page
    And I click on group milestones
    Then I should see group milestones index page with milestones

  Scenario: I should see group "Owned" milestone show page
    Given Group has projects with milestones
    When I visit group "Owned" page
    And I click on group milestones
    And I click on one group milestone
    Then I should see group milestone with descriptions and expiry date
    And I should see group milestone with all issues and MRs assigned to that milestone

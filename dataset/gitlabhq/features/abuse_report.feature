Feature: Abuse reports
  Background:
    Given I sign in as a user
    And user "Mike" exists

  Scenario: Report abuse
    Given I visit "Mike" user page
    And I click "Report abuse" button
    When I fill and submit abuse form
    Then I should see success message

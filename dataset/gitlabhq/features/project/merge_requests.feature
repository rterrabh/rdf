Feature: Project Merge Requests
  Background:
    Given I sign in as a user
    And I own project "Shop"
    And project "Shop" have "Bug NS-04" open merge request
    And project "Shop" have "Feature NS-03" closed merge request
    And I visit project "Shop" merge requests page

  Scenario: I should see open merge requests
    Then I should see "Bug NS-04" in merge requests
    And I should not see "Feature NS-03" in merge requests

  Scenario: I should see rejected merge requests
    Given I click link "Closed"
    Then I should see "Feature NS-03" in merge requests
    And I should not see "Bug NS-04" in merge requests

  Scenario: I should see all merge requests
    Given I click link "All"
    Then I should see "Feature NS-03" in merge requests
    And I should see "Bug NS-04" in merge requests

  Scenario: I visit merge request page
    Given I click link "Bug NS-04"
    Then I should see merge request "Bug NS-04"

  Scenario: I close merge request page
    Given I click link "Bug NS-04"
    And I click link "Close"
    Then I should see closed merge request "Bug NS-04"

  Scenario: I reopen merge request page
    Given I click link "Bug NS-04"
    And I click link "Close"
    Then I should see closed merge request "Bug NS-04"
    When I click link "Reopen"
    Then I should see reopened merge request "Bug NS-04"

  Scenario: I submit new unassigned merge request
    Given I click link "New Merge Request"
    And I submit new merge request "Wiki Feature"
    Then I should see merge request "Wiki Feature"

  Scenario: I download a diff on a public merge request
    Given public project "Community"
    And "John Doe" owns public project "Community"
    And project "Community" has "Bug CO-01" open merge request with diffs inside
    Given I logout directly
    And I visit merge request page "Bug CO-01"
    And I click on "Email Patches"
    Then I should see a patch diff
    And I visit merge request page "Bug CO-01"
    And I click on "Plain Diff"
    Then I should see a patch diff

  @javascript
  Scenario: I comment on a merge request
    Given I visit merge request page "Bug NS-04"
    And I leave a comment like "XML attached"
    Then I should see comment "XML attached"

  @javascript
  Scenario: I comment on a merge request diff
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I leave a comment like "Line is wrong" on diff
    And I switch to the merge request's comments tab
    Then I should see a discussion has started on diff

  @javascript
  Scenario: I comment on a line of a commit in merge request
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the commit in the merge request
    And I leave a comment like "Line is wrong" on diff in commit
    And I switch to the merge request's comments tab
    Then I should see a discussion has started on commit diff

  @javascript
  Scenario: I comment on a commit in merge request
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the commit in the merge request
    And I leave a comment on the diff page in commit
    And I switch to the merge request's comments tab
    Then I should see a discussion has started on commit

  @javascript
  Scenario: I accept merge request with custom commit message
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And merge request "Bug NS-05" is mergeable
    And I visit merge request page "Bug NS-05"
    And merge request is mergeable
    Then I modify merge commit message
    And I accept this merge request
    Then I should see merged request

  # Markdown

  Scenario: Headers inside the description should have ids generated for them.
    When I visit merge request page "Bug NS-04"
    Then Header "Description header" should have correct id and link

  @javascript
  Scenario: Headers inside comments should not have ids generated for them.
    Given I visit merge request page "Bug NS-04"
    And I leave a comment with a header containing "Comment with a header"
    Then The comment with the header should not have an ID

  # Toggling inline comments

  @javascript
  Scenario: I hide comments on a merge request diff with comments in a single file
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I leave a comment like "Line is wrong" on line 39 of the second file
    And I click link "Hide inline discussion" of the second file
    Then I should not see a comment like "Line is wrong here" in the second file

  @javascript
  Scenario: I show comments on a merge request diff with comments in a single file
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I leave a comment like "Line is wrong" on line 39 of the second file
    Then I should see a comment like "Line is wrong" in the second file

  @javascript
  Scenario: I hide comments on a merge request diff with comments in multiple files
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I leave a comment like "Line is correct" on line 12 of the first file
    And I leave a comment like "Line is wrong" on line 39 of the second file
    And I click link "Hide inline discussion" of the second file
    Then I should not see a comment like "Line is wrong here" in the second file
    And I should still see a comment like "Line is correct" in the first file

  @javascript
  Scenario: I show comments on a merge request diff with comments in multiple files
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I leave a comment like "Line is correct" on line 12 of the first file
    And I leave a comment like "Line is wrong" on line 39 of the second file
    And I click link "Hide inline discussion" of the second file
    And I click link "Show inline discussion" of the second file
    Then I should see a comment like "Line is wrong" in the second file
    And I should still see a comment like "Line is correct" in the first file

  @javascript
  Scenario: I unfold diff
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I unfold diff
    Then I should see additional file lines

  @javascript
  Scenario: I show comments on a merge request side-by-side diff with comments in multiple files
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    And I leave a comment like "Line is correct" on line 12 of the first file
    And I leave a comment like "Line is wrong" on line 39 of the second file
    And I click Side-by-side Diff tab
    Then I should see comments on the side-by-side diff page

  @javascript
  Scenario: I view diffs on a merge request
    Given project "Shop" have "Bug NS-05" open merge request with diffs inside
    And I visit merge request page "Bug NS-05"
    And I click on the Changes tab
    Then I should see the proper Inline and Side-by-side links

  # Description preview

  @javascript
  Scenario: I can't preview without text
    Given I visit merge request page "Bug NS-04"
    And I click link "Edit" for the merge request
    And I haven't written any description text
    Then The Markdown preview tab should say there is nothing to do

  @javascript
  Scenario: I can preview with text
    Given I visit merge request page "Bug NS-04"
    And I click link "Edit" for the merge request
    And I write a description like ":+1: Nice"
    Then The Markdown preview tab should display rendered Markdown

  @javascript
  Scenario: I preview a merge request description
    Given I visit merge request page "Bug NS-04"
    And I click link "Edit" for the merge request
    And I preview a description text like "Bug fixed :smile:"
    Then I should see the Markdown preview
    And I should not see the Markdown text field

  @javascript
  Scenario: I can edit after preview
    Given I visit merge request page "Bug NS-04"
    And I click link "Edit" for the merge request
    And I preview a description text like "Bug fixed :smile:"
    Then I should see the Markdown write tab

  @javascript
  Scenario: I search merge request
    Given I click link "All"
    When I fill in merge request search with "Fe"
    Then I should see "Feature NS-03" in merge requests
    And I should not see "Bug NS-04" in merge requests

  @javascript
  Scenario: I can unsubscribe from merge request
    Given I visit merge request page "Bug NS-04"
    Then I should see that I am subscribed
    When I click button "Unsubscribe"
    Then I should see that I am unsubscribed

  @javascript
  Scenario: I can change the target branch
    Given I visit merge request page "Bug NS-04"
    And I click link "Edit" for the merge request
    When I click the "Target branch" dropdown
    And I select a new target branch
    Then I should see new target branch changes

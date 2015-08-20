

Feature: Test the content of the 'automation for the people' page

  Scenario:
    Given The EC2 instance is deployed
    When The welcome page is loaded
    Then The page contains the text "Automation for the people"
    Then The HTTP status code is 200

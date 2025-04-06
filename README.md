# CodeOwners

Use the CodeOwners system to define who owns specific parts of your repository and prevent code from being merged into the master/main branch of your GitLab repository without approvals from the owners of the modified files/folders.

The main idea behind CodeOwners is to enhance the security of the code being merged into the repository.

> This system is similar to [GitLab's Code Owners](https://docs.gitlab.com/user/project/codeowners/), but it has several key differences:
> 
> - Does not require a paid version of GitLab.
> - Can be infinitely improved, expanded, and integrated with other services by your developers.
> - Has a convenient UI for setting up the team list.

### Key Features

- Integration with GitLab.
- Maintains a list of teams and the folders/files they are responsible for. Users can belong to one or more teams. A team can be responsible for a specific file, folder, or a set of files.
- The possibility of a super-like from a specific team. In this case, it is not necessary to gather approvals from other teams to merge the request.
- Automatic assignment of reviewers based on modified resources. That is, teams whose files were changed will be assigned for review.
- Automatic assignment of random reviewers for files that have no owners.
- Notifications via comments in merge requests and messages in MatterMost regarding the assignment of approvers.
- Approval tracking to allow merge requests to be merged into master/main.

**For a merge request to be merged, the following conditions must be met:**

- At least one approval must be received from each team whose files were changed.
- The total number of approvals must be at least two.

This repository contains all the necessary components to implement CodeOwners in your working project.

## Usage

### Step 1. Create the `codeowners.json` file

The `codeowners.json` file contains data about teams, users, and the paths they are responsible for. This file must be placed in the root directory of the repository where the system is being connected. You can find an example of a filled-out file in the root of this repository.

### Step 2. Fill in the data

Now, you need to fill out the `codeowners.json` file according to your project. Three options are available:

#### Option 1. Fill the file manually

You can fill the file manually according to the provided example (see the `codeowners.json` file in the root of this repository).

#### Option 2. Use RaifMagic

If your project supports the use of RaifMagic, you can set up this file via a convenient interface.

#### Option 3. Develop your own GUI application

The repository includes an SPM package that has all the necessary components for developing your own graphical application to work with CodeOwners.

> It is assumed that development will take place in Xcode on macOS.

The package includes two products:

- `CodeOwners` provides a service for working with the `codeowners.json` file and GitLab to get the GitLab user ID.
- `CodeOwnersSwiftUI` provides a pre-implemented interface for working with CodeOwners. You can use it when implementing your own application or create your own interface.

Follow these steps:

- In Xcode, create a new macOS application project. Choose SwiftUI as the main framework.
- Integrate the SPM package from this repository into your project.
- Include the `CodeOwners` and `CodeOwnersSwiftUI` products.
- Integrate the `CodeOwnersView` into the UI of your application.

### Step 3. Integration with CI

The CodeOwners system in CI involves performing two tasks:

1. Assigning reviewers according to the list of modified files and data from the `codeowners.json` file.
2. Checking approvals from reviewers.

Both tasks should be performed within your CI pipeline.

Let's break down each task in more detail.

#### Assigning Reviewers

To assign reviewers, add the script call `/CI_scripts/setCodeOwners.py` to your pipeline.

> Important: The script does not assign reviewers for merge requests in Draft mode.

To make it work, create the following environment variables:

- `CI_MERGE_REQUEST_SOURCE_BRANCH_NAME` - the name of the branch being merged into master/main.
- `CI_JOB_NAME` - the name of the job in which the script is being run.
- `CODEOWNERS_TEAM_EXCLUDE` - a list of team names to exclude from the random reviewer assignment.

#### Checking Reviewers

To check the reviewers, add the script call `/CI_scripts/checkCodeOwners.py` to your pipeline. When the task runs, if the required number of approvals is collected, the task will be successful and will not block the merge request.

To make it work, create the following environment variables:

- `CI_MERGE_REQUEST_SOURCE_BRANCH_NAME` - the name of the branch being merged into master/main.
- `CI_JOB_NAME` - the name of the job in which the script is being run.
# Workflow for Adding New Functions to scripts

This document outlines the standard procedure for developing, integrating, and documenting new functionality within the scripts. Following this workflow ensures that all changes are consistent, tested, and adhere to project conventions.

---

### Phase 1: Research and Discovery

Before writing any code, thoroughly understand the user's intent.

1.  **Ask for confirmation of your current understanding of the requirement**: Summarize what you beleive the user has asked you to do. Ask the user if this is correct.
2.  **Update your understanding of the requirements based on the user's response**: restate your understanding of the user's intent. repeat this process until the user explicitly says to proceed.


---

### Phase 2: Isolated Development and Testing

Develop the new functionality in a temporary, standalone script to avoid impacting the main script during development.

1.  **Create a Temporary Script**: Create a new script for your feature (e.g., `temp_new_feature.sh`). Make it executable with `chmod +x`.
2.  **Build the Core Function**: Write the new function inside this temporary script.
3.  **Parameterize and Generalize**: Do not hardcode values or arguments. The function should accept parameters (like a customer ID).
4.  **Test Thoroughly**: If the function requires arguments, Run the standalone script against multiple variations (suggest a range of options to the user) to ensure the function is robust, handles edge cases, and fails gracefully with clear error messages.

---

### Phase 3: Integration into main script

Once the function is complete and tested, integrate it into the main script.

1.  **Create New Version**: Copy the latest version of the main script to a new, incremented version file (e.g., `cp scripts/myscript-v1.26.sh scripts/myscript-v1.27.sh`).
2.  **Copy the Function**: Copy the finalized, tested function from your temporary script and paste it into the `--- Core Functions ---` section of the new `myscript-vX.XX.sh` file.
3.  **Determine Integration Points**:
    *   If the function should be available as a standalone command, proceed to the next phase.

---

### Phase 4: Documentation and Finalization

Update all user-facing documentation and finalize the release.

1.  **Update Changelog**: In the header of the new `mcript-vX.XX.sh` file, add a new entry describing the changes for the new version.
2.  **Update Usage Information**:
    *   If you added a new standalone command, add it to the `usage()` function.
    *   Update the main `case` statement in the `--- Main Argument Parsing ---` section to handle the new command and its arguments.
3.  **Update `README.md`**: Add the new command to the command reference table in the main `README.md` file.
4.  **Update Main Script File**: Copy the new version to the root directory, overwriting the old master script (`cp scripts/myscript-vX.XX.sh myscript.sh`).
5.  **Security Concerns**: make sure you do not push sensitive files contained in an 'auth' or 'cred' directory. these should be noted in the .gitignore file. if you are unsure, check with the user before you commit.
6.  **Commit and Push**: Use `git add` to stage the new version file, the updated main script, and the `README.md`. Commit the changes with a clear, descriptive message and push to the remote repository.


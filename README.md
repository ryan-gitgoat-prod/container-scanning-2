# Container Scanning 2 - Annotation-Based Auto-Linking Demo - Yes

This repository demonstrates **Arnica's annotation-based container-to-source auto-linking** for Node.js-based containers.

## What This Tests

When a container image is pushed to a registry, Arnica can automatically link it back to the source Dockerfile in your repository using two methods:

1. **Annotation-based linking** (deterministic, high confidence) - uses OCI labels embedded in Dockerfiles
2. **Heuristic linking** (probabilistic, lower confidence) - analyzes container build history

**This repository tests method #1: Annotation-based linking with OCI annotations.**

### How Annotation-Based Linking Works

1. Arnica policy automatically adds OCI annotation labels to your Dockerfiles by committing to the PR branch
2. These labels embed metadata directly in the Dockerfile:
   ```dockerfile
   LABEL org.opencontainers.image.source="https://github.com/YOUR_ORG/YOUR_REPO"
   LABEL org.opencontainers.image.path="path/to/Dockerfile"
   ```
3. When you build and push the image, these labels become part of the image metadata
4. Arnica scans your container registry and reads these labels
5. Arnica deterministically links the container back to the exact Dockerfile
6. Assignment type: `labels` (confidence score: 100, but we should be removing confidence soon)

This approach requires modifying Dockerfiles but provides deterministic, high-confidence linking.

---

## Files in This Repository

```
awesome-content.Dockerfile  - Sample Dockerfile with intentional vulnerabilities
package.json              - Node.js dependencies (some with known CVEs)
package-lock.json         - Lockfile for Node.js dependencies
image.png                 - Screenshot of policy configuration
README.md                 - This file
```

**Note:** The Dockerfile intentionally includes:
- `libxml` package installed via RUN command (has known CVEs)
- `http-proxy-agent@1.0.0` in package.json (has known CVEs)
- Dependencies that will trigger vulnerability findings

---

## Setup Instructions

### Prerequisites

- GitHub account with a repository where you'll test this
- Docker installed locally
- GitHub Container Registry (GHCR) access configured
- Arnica account with container scanning enabled
- Arnica must have **write permissions** to push commits to your repository

### Step 1: Copy Files to Your Test Repository

```bash
# Set your destination repository path
DEST_REPO="/path/to/your/test/repo"

# Copy the test files
cp awesome-content.Dockerfile "$DEST_REPO/"
cp package.json "$DEST_REPO/"
cp package-lock.json "$DEST_REPO/"

echo "✓ Files copied to $DEST_REPO"
```

### Step 2: Commit and Push to Main Branch

```bash
cd "$DEST_REPO"
git add awesome-content.Dockerfile package.json package-lock.json
git commit -m "Add annotation-based linking test Dockerfile"
git push origin main
```

### Step 3: Integrate Repository with Arnica

1. Log into Arnica
2. Go to **Settings** → **Integrations** → **GitHub**
3. Add your test repository (if not already added)
4. **Verify Arnica has write permissions** (required to push commits)
5. Wait 1-2 minutes for initial sync

### Step 4: Integrate Container Registry with Arnica

1. In Arnica: **Settings** → **Integrations** → **Container Registries**
2. Add GitHub Container Registry (GHCR) integration
3. Follow the setup guide: [Container Integrations Documentation](https://docs.arnica.io/arnica-documentation/getting-started/container-integrations/ghcr)
4. Ensure container scanning correlation is enabled for your tenant 

### Step 5: Configure Policy to Tag Dockerfiles

This is the key step that enables annotation-based linking.

1. In Arnica: **Policies** → **Create New Policy** (or edit existing "Tag Dockerfiles" policy)
2. Configure:
   - **Name**: "Dockerfile Annotation Tagging - Node.js"
   - **Type**: Code Risk
   - **Trigger**: **On Pull Request Created** (this is the only supported trigger for Tag Dockerfiles)
   - **Scope**: Apply to your test repository
   - **Conditions** (these determine WHEN the policy runs, not which files are tagged):
     - **Optional:** Add file path condition like `*.Dockerfile` to only trigger when Dockerfiles change
     - **Optional:** Add `package*.json` to also trigger when dependencies change
     - **Note:** Once triggered, the policy will tag **ALL Dockerfiles in the repository**, not just the ones changed in the PR
   - **Actions**: Select "Tag/Label Dockerfiles" action
     - **"Add image source"** is enabled by default (adds `org.opencontainers.image.source` label)
     - ✅ Enable **"Add image path"** (adds `org.opencontainers.image.path` label)
     - Optional: Add custom message
3. Save the policy

![Policy Configuration Example](image.png)

### Step 6: Trigger the Policy to Tag Your Dockerfile

**Important:** The policy only triggers on **Pull Request Created**, so you must create a PR (not push directly to main).

```bash
cd "$DEST_REPO"

# Create a new branch
git checkout -b test-annotations

# Make a small change to trigger the policy
# (Any change works, but modifying a Dockerfile ensures the policy is triggered if you have file path conditions)
echo "# Testing annotation-based linking" >> awesome-content.Dockerfile
git add awesome-content.Dockerfile
git commit -m "Test: Trigger Arnica annotation policy"
git push origin test-annotations

# Create PR via GitHub UI or CLI
gh pr create --title "Test: Add Dockerfile annotations" --body "Testing Arnica's annotation-based linking"
```

**What happens next:**
- Arnica detects that a PR was created
- Within 1-2 minutes, Arnica will scan **ALL Dockerfiles in the repository** and add OCI annotations to any that need them
- Arnica will add a **new commit** to your PR branch with the OCI labels
- The commit message will be: `chore(security): add OCI annotations to Dockerfiles`
- The updated Dockerfile will look like:
  ```dockerfile
  # ================ ARNICA SECURITY ANNOTATION BLOCK START ================
  LABEL org.opencontainers.image.source="https://github.com/YOUR_ORG/YOUR_REPO"
  LABEL org.opencontainers.image.path="awesome-content.Dockerfile"
  # These automated labels, added by the security team, enhance traceability and security.
  # For more details, see: https://docs.arnica.io/arnica-documentation/developers/adding-oci-tags-to-docker-images.
  # To exclude this file, please replace this change with: #arnica-ignore followed by the dismissal reason.
  # ================ ARNICA SECURITY ANNOTATION BLOCK END ================
  
  FROM node:22.18.0-bullseye
  ...
  ```

### Step 7: Merge the Annotations and Build the Image

1. **Refresh your PR** - you should see Arnica's commit adding the OCI annotations
2. **Merge the PR** to get the annotations into your main branch

```bash
# After merging the PR, pull the latest changes
git checkout main
git pull origin main
```

3. **Build and push the Docker image with the annotations:**

```bash
cd "$DEST_REPO"

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Build the image (annotations are now embedded in the image)
docker build -f awesome-content.Dockerfile -t ghcr.io/YOUR_ORG/container-scanning-2:latest .

# Push the image
docker push ghcr.io/YOUR_ORG/container-scanning-2:latest
```

**Important:** Replace `YOUR_ORG` and `YOUR_GITHUB_USERNAME` with your actual values.

### Step 8: Verify Auto-Linking

1. Wait 2-5 minutes for Arnica to scan the container registry
2. Go to **Inventory** → **Container Images** in Arnica
3. Find your image: `ghcr.io/YOUR_ORG/container-scanning-2`
4. Click on the image to view details
5. Check the **"Source Code Location"** section:
   - **Expected:** Repository and Dockerfile path should be automatically detected
   - **Assignment Type:** Should show `labels` (annotation-based matching)
   - **Confidence:** 100 (high confidence due to deterministic matching)
6. Click **"View in Repository"** to navigate to the linked Dockerfile

### Step 9: View Vulnerabilities

1. In the container image details, click the **Vulnerabilities** tab
2. You should see CVEs detected in:
   - `libxml` package
   - `http-proxy-agent@1.0.0`
   - Other dependencies from `package.json`
   - Base image `node:22.18.0-bullseye`
3. Click **"View findings linked to source code repository"** to see CVEs correlated to your source repo
4. Vulnerabilities may be linked to specific lines in `package.json` and the Dockerfile (when line information is available)

**Note:** Vulnerability correlation to source code only happens if:
- The container is successfully linked to a repository (check "Source Code Location" is populated)
- Container scanning correlation is enabled for your tenant
- The repository has been scanned by Arnica

---

## How to Verify This is Annotation-Based Linking

1. **Check the Dockerfile** - it should contain OCI labels:
   ```dockerfile
   # ================ ARNICA SECURITY ANNOTATION BLOCK START ================
   LABEL org.opencontainers.image.source="https://github.com/..."
   LABEL org.opencontainers.image.path="..."
   # These automated labels, added by the security team, enhance traceability and security.
   # For more details, see: https://docs.arnica.io/arnica-documentation/developers/adding-oci-tags-to-docker-images.
   # To exclude this file, please replace this change with: #arnica-ignore followed by the dismissal reason.
   # ================ ARNICA SECURITY ANNOTATION BLOCK END ================
   ```

2. **Check Assignment Type in Arnica:**
   - Navigate to the container image details in Arnica
   - Look for **"Assignment Type: labels"** (not "lines")
   - Confidence should be 100

3. **Inspect the Docker image metadata:**
   ```bash
   docker pull ghcr.io/YOUR_ORG/container-scanning-2:latest
   docker inspect ghcr.io/YOUR_ORG/container-scanning-2:latest | grep -A 5 "Labels"
   ```
   You should see the `org.opencontainers.image.source` and `org.opencontainers.image.path` labels.

---

## Troubleshooting

### Arnica Didn't Add Annotations to My Dockerfile

**Possible causes:**
- Policy not configured correctly (must use "On Pull Request Created" trigger)
- Arnica doesn't have write permissions to your repository
- Policy scope doesn't include your repository
- Policy was triggered on push/merge instead of PR creation
- Policy conditions not met (e.g., file path condition requires Dockerfile changes but PR doesn't have any)

**Solutions:**
1. Verify policy trigger is set to **"On Pull Request Created"** (not "On Push" or other triggers)
2. Check policy configuration in Arnica → **Policies** → Your policy
3. Verify policy scope includes your repository
4. Check Arnica integration has write permissions: **Settings** → **Integrations** → **GitHub**
5. Check **Jobs** → **Recent Tasks** for any errors
6. Create a new PR (not push to main); if you have file path conditions, ensure the PR modifies a Dockerfile or matching file

### Container Not Linked to Repository

**Possible causes:**
- Image was built before annotations were added
- Annotations were not properly embedded in the image
- Container registry not yet scanned by Arnica

**Solutions:**
1. Verify the Dockerfile contains the LABEL directives
2. Rebuild and push the image to include the annotations
3. Wait 5-10 minutes for Arnica to scan the registry
4. Check **Jobs** → **Container Scans** for scan status

### Container Shows "lines" Assignment Type Instead of "labels"

**Cause:** Image was built without the OCI annotations.

**Solution:**
1. Verify the Dockerfile in your repository contains the LABEL directives
2. Pull the latest version of the Dockerfile: `git pull origin main`
3. Rebuild the image: `docker build -f awesome-content.Dockerfile ...`
4. Push the rebuilt image: `docker push ...`
5. Wait 5 minutes and check again

### No Vulnerabilities Showing

**Cause:** Container scan may still be in progress.

**Solution:**
- Wait 5-10 minutes after pushing the image
- Check **Jobs** → **Container Scans** for scan status
- Verify your container registry integration is working


---

## Next Steps

After testing annotation-based linking, compare the results with **container-scanning-1** to understand the trade-offs between the two approaches.

## Links to docs

- [Container Images Documentation](https://docs.arnica.io/arnica-documentation/inventory/container-images)
- [Adding OCI Tags to Docker Images](https://docs.arnica.io/arnica-documentation/developers/adding-oci-tags-to-docker-images)
- [Container Integrations](https://docs.arnica.io/arnica-documentation/getting-started/container-integrations/ghcr)
- [OCI Image Spec - Annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md)

# GitHub Actions Secrets Setup

To enable automated releases with GitHub Actions, you need to configure these secrets in your repository.

## Required Secrets

Go to: `github.com/den-kim/calendarplusplus` → Settings → Secrets and variables → Actions → New repository secret

### 1. DEVELOPER_ID_CERTIFICATE

Your Developer ID Application certificate as Base64.

**Steps:**
```bash
# Export certificate from Keychain
# 1. Open Keychain Access
# 2. Find "Developer ID Application: Your Name (TEAM_ID)"
# 3. Right-click → Export
# 4. Save as certificate.p12
# 5. Set a strong password (you'll need this for CERTIFICATE_PASSWORD)

# Convert to Base64
base64 -i certificate.p12 | pbcopy

# The Base64 string is now in your clipboard
# Paste it as the secret value
```

**Security:** Delete `certificate.p12` after encoding!

### 2. CERTIFICATE_PASSWORD

The password you used when exporting the certificate.

**Example:** `YourStrongPassword123!`

### 3. APPLE_ID

Your Apple ID email address.

**Example:** `your@email.com`

### 4. APPLE_ID_PASSWORD

App-specific password (NOT your regular Apple ID password).

**Steps to create:**
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign In → Security → App-Specific Passwords
3. Click "+" to generate new password
4. Label: "GitHub Actions Notarization"
5. Copy the password (format: `xxxx-xxxx-xxxx-xxxx`)

**Example:** `abcd-efgh-ijkl-mnop`

### 5. TEAM_ID

Your Apple Developer Team ID.

**Find it:**
1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Membership → Team ID
3. Copy the 10-character ID

**Example:** `AB12CD34EF`

## Testing the Workflow

Once all secrets are configured:

```bash
# Create and push a test tag
git tag -a v1.0.0-test -m "Test release"
git push origin v1.0.0-test

# Watch the workflow
# Go to: github.com/den-kim/calendarplusplus/actions
```

## Troubleshooting

### Certificate not found
- Verify certificate is valid Developer ID Application
- Check certificate hasn't expired
- Ensure Base64 encoding is complete (no truncation)

### Notarization failed
- Verify Apple ID credentials are correct
- Check app-specific password is valid
- Ensure Team ID matches your account
- Review notarization logs in Actions output

### Build failed
- Check Xcode version in workflow matches your local version
- Verify Info.plist path is correct
- Ensure all dependencies are available

## Security Best Practices

✅ **DO:**
- Use app-specific passwords (never regular password)
- Rotate secrets periodically
- Delete exported certificates after encoding
- Use strong passwords for certificate export

❌ **DON'T:**
- Commit certificates or passwords to git
- Share secrets with others
- Use same password across services
- Leave exported certificates on disk

## Alternative: Manual Releases

If you prefer not to use GitHub Actions, you can still release manually:

```bash
# Build locally
./build-release.sh 1.0.0

# Create GitHub release manually
# Upload the ZIP file
# Update Homebrew formula with new SHA256
```

## Need Help?

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Keychain Certificate Management](https://support.apple.com/guide/keychain-access)

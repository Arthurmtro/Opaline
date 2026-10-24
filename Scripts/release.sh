#!/bin/zsh
# Builds a universal app signed with your Developer ID, has Apple notarize it, publishes it as a GitHub release
# and points the Homebrew cask at it. Signing and notarization use the Apple account signed in to Xcode.
# Usage: OPALINE_TEAM_ID=<team id> Scripts/release.sh <version>
set -euo pipefail

version=${1:?usage: OPALINE_TEAM_ID=<team id> Scripts/release.sh <version>}
team=${OPALINE_TEAM_ID:?set OPALINE_TEAM_ID to the Apple team that signs the release}
repo=Arthurmtro/Opaline
tap=Arthurmtro/homebrew-tap
cd "${0:A:h}/.."
[[ -z $(git status --porcelain) ]] || { print -u2 "Commit or stash your changes first."; exit 1; }
[[ $(git rev-parse --abbrev-ref HEAD) == main ]] || { print -u2 "Release from main."; exit 1; }

out=.build/release/$version
archive=$out/Opaline.xcarchive
zip=$out/Opaline-$version-macOS.zip
command rm -rf $out && mkdir -p $out

xcodegen generate --quiet
xcodebuild -project Opaline.xcodeproj -scheme Opaline -configuration Release -archivePath $archive \
  -derivedDataPath $out/derived archive -allowProvisioningUpdates -quiet \
  DEVELOPMENT_TEAM=$team CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
  MARKETING_VERSION=$version CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)

cat > $out/options.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>upload</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath $archive -exportOptionsPlist $out/options.plist -exportPath $out/upload \
  -allowProvisioningUpdates -quiet

print "Waiting for Apple to notarize the app…"
for attempt in {1..60}; do
  xcodebuild -exportNotarizedApp -archivePath $archive -exportPath $out/app >/dev/null 2>&1 && break
  (( attempt == 60 )) && { print -u2 "Notarization did not finish in 15 minutes."; exit 1; }
  sleep 15
done
spctl --assess --type execute $out/app/Opaline.app
ditto -c -k --keepParent $out/app/Opaline.app $zip
sha=$(shasum -a 256 $zip | cut -d' ' -f1)

git tag v$version && git push origin v$version
gh release create v$version $zip --repo $repo --title "Opaline $version" --generate-notes

cask=$(cat <<RUBY
cask "opaline" do
  version "$version"
  sha256 "$sha"

  url "https://github.com/$repo/releases/download/v#{version}/Opaline-#{version}-macOS.zip"
  name "Opaline"
  desc "Design one color theme and apply it to your terminal, editor, browser and wallpaper"
  homepage "https://github.com/$repo"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sequoia"

  app "Opaline.app"

  zap trash: [
    "~/Library/Application Support/Opaline",
    "~/Library/Preferences/app.opaline.Opaline.plist",
  ]
end
RUBY
)
current=$(gh api repos/$tap/contents/Casks/opaline.rb --jq .sha 2>/dev/null || true)
update=(-f message="opaline $version" -f content="$(print -r -- $cask | base64)")
[[ -n $current ]] && update+=(-f sha=$current)
gh api -X PUT repos/$tap/contents/Casks/opaline.rb $update --silent
print "Released $version: brew upgrade --cask opaline"

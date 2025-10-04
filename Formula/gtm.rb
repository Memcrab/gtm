class Gtm < Formula
  desc "Simple, automatic Git time tracking"
  homepage "https://github.com/memcrab/gtm"
  url "https://github.com/memcrab/gtm.git",
      revision: "d0c43d7f42878f9242ac11240733267cdd83b500"
  version "1.4.0"
  license "MIT"
  head "https://github.com/memcrab/gtm.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "git" => :build
  depends_on "go" => :build
  depends_on "pkg-config" => :build

  def install
    ENV["GOCACHE"] = buildpath/"gocache"
    ENV["GOMODCACHE"] = buildpath/"gomodcache"
    ENV["HOME"] = buildpath/"home"

    system "make", "build"
    bin.install "bin/gtm"
  end

  test do
    assert_match "Usage: gtm", shell_output("#{bin}/gtm --help")
  end
end

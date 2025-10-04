package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type dependency struct {
	ImportPath string `json:"importpath"`
	Repository string `json:"repository"`
	VCS        string `json:"vcs"`
	Revision   string `json:"revision"`
}

type manifest struct {
	Dependencies []dependency `json:"dependencies"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

func run() error {
	root, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("determine working directory: %w", err)
	}

	manifestPath := filepath.Join(root, "vendor", "manifest")
	f, err := os.Open(manifestPath)
	if err != nil {
		return fmt.Errorf("open manifest: %w", err)
	}
	defer f.Close()

	var m manifest
	dec := json.NewDecoder(f)
	if err := dec.Decode(&m); err != nil {
		return fmt.Errorf("decode manifest: %w", err)
	}

	gopathRoot := filepath.Join(root, ".gopath", "src")

	for _, dep := range m.Dependencies {
		if dep.ImportPath == "" || dep.Repository == "" || dep.Revision == "" {
			fmt.Fprintf(os.Stderr, "skipping incomplete dependency entry: %+v\n", dep)
			continue
		}
		if dep.VCS != "git" && dep.VCS != "" {
			fmt.Fprintf(os.Stderr, "skipping unsupported VCS (%s) for %s\n", dep.VCS, dep.ImportPath)
			continue
		}

		destDir := filepath.Join(gopathRoot, filepath.FromSlash(dep.ImportPath))
		if err := os.MkdirAll(filepath.Dir(destDir), 0o755); err != nil {
			return fmt.Errorf("create parent for %s: %w", destDir, err)
		}

		if _, err := os.Stat(destDir); errors.Is(err, os.ErrNotExist) {
			if err := runCmd(root, "git", "clone", dep.Repository, destDir); err != nil {
				return fmt.Errorf("clone %s: %w", dep.ImportPath, err)
			}
		} else if err == nil {
			if matchesRevision(destDir, dep.Revision) {
				continue
			}
			if revExists(destDir, dep.Revision) {
				// revision already present locally
			} else if err := runCmd(destDir, "git", "fetch", "--all", "--tags", "--prune"); err != nil {
				return fmt.Errorf("fetch %s: %w", dep.ImportPath, err)
			}
		} else {
			return fmt.Errorf("stat %s: %w", destDir, err)
		}

		if err := runCmd(destDir, "git", "checkout", "-qf", dep.Revision); err != nil {
			return fmt.Errorf("checkout %s@%s: %w", dep.ImportPath, dep.Revision, err)
		}
	}

	return nil
}

func matchesRevision(dir, revision string) bool {
	out, err := runCmdOutput(dir, "git", "rev-parse", "HEAD")
	if err != nil {
		return false
	}
	return strings.TrimSpace(out) == revision
}

func revExists(dir, revision string) bool {
	_, err := runCmdOutput(dir, "git", "rev-parse", "--verify", revision+"^{commit}")
	return err == nil
}

func runCmd(dir string, name string, args ...string) error {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runCmdOutput(dir string, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}
	return string(out), nil
}

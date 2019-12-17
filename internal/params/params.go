package params

import libparams "github.com/qdm12/golibs/params"

import "fmt"

// GetUser obtains the user to use to connect to the VPN servers
func GetUser() (s string, err error) {
	s = libparams.GetEnv("USER", "")
	if len(s) == 0 {
		return s, fmt.Errorf("USER environment variable cannot be empty")
	}
	return s, nil
}

// GetPassword obtains the password to use to connect to the VPN servers
func GetPassword() (s string, err error) {
	s = libparams.GetEnv("PASSWORD", "")
	if len(s) == 0 {
		return s, fmt.Errorf("PASSWORD environment variable cannot be empty")
	}
	return s, nil
}

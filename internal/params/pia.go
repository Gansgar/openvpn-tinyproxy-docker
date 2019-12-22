package params

import (
	"fmt"

	libparams "github.com/qdm12/golibs/params"
	"github.com/qdm12/private-internet-access-docker/internal/constants"
)

// GetPortForwarding obtains if port forwarding on the VPN provider server
// side is enabled or not from the environment variable PORT_FORWARDING
func GetPortForwarding() (activated bool, err error) {
	s := libparams.GetEnv("PORT_FORWARDING", "off")
	if s == "false" || s == "off" {
		return false, nil
	} else if s == "true" || s == "on" {
		return true, nil
	}
	return false, fmt.Errorf("PORT_FORWARDING can only be \"on\" or \"off\"")
}

// GetPortForwardingStatusFilepath obtains the port forwarding status file path
// from the environment variable PORT_FORWARDING_STATUS_FILE
func GetPortForwardingStatusFilepath() (filepath string, err error) {
	return libparams.GetPath("PORT_FORWARDING_STATUS_FILE", "/forwarded_port")
}

// GetPIAEncryption obtains the encryption level for the PIA connection
// from the environment variable ENCRYPTION
func GetPIAEncryption() (constants.PIAEncryption, error) {
	s, err := libparams.GetValueIfInside("ENCRYPTION", []string{"normal", "strong"}, false, "strong")
	return constants.PIAEncryption(s), err
}

// GetPIARegion obtains the region for the PIA server from the
// environment variable REGION
func GetPIARegion() (constants.PIARegion, error) {
	s, err := libparams.GetValueIfInside("REGION", []string{"Netherlands"}, true, "")
	return constants.PIARegion(s), err
}
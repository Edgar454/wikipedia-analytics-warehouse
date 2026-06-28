import os
import sys
from deployer import PowerBIDeployer


pbix_path = os.getenv("DASHBOARD_PBIX_PATH", "dashboards/dashboard.pbix")

if not os.path.isfile(pbix_path):
    sys.exit(f"DASHBOARD_PBIX_PATH does not exist: {pbix_path}")

deployer = PowerBIDeployer(pbix_path)
deployer.deploy()

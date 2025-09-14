#!/usr/bin/env python3

import json
import subprocess
import sys
import base64
from typing import Dict, Any
import argparse
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SecretManager:
    def __init__(self, project_id: str):
        self.project_id = project_id

    def get_secret(self, secret_name: str) -> str:
        """Get secret value from GCP Secret Manager"""
        try:
            cmd = [
                'gcloud', 'secrets', 'versions', 'access', 'latest',
                '--secret', secret_name,
                '--project', self.project_id
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()

        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to get secret {secret_name}: {e.stderr}")
            raise

    def list_secrets(self) -> list:
        """List all secrets in Secret Manager"""
        try:
            cmd = [
                'gcloud', 'secrets', 'list',
                '--project', self.project_id,
                '--format', 'json'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout)

        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to list secrets: {e.stderr}")
            raise

class KubernetesSecretManager:
    def __init__(self):
        pass

    def create_secret(self, secret_name: str, data: Dict[str, str], namespace: str = 'default') -> bool:
        """Create or update a Kubernetes secret"""
        try:
            # Check if secret exists
            check_cmd = ['kubectl', 'get', 'secret', secret_name, '-n', namespace]
            secret_exists = subprocess.run(check_cmd, capture_output=True).returncode == 0

            # Prepare kubectl command
            if secret_exists:
                # Delete existing secret
                delete_cmd = ['kubectl', 'delete', 'secret', secret_name, '-n', namespace]
                subprocess.run(delete_cmd, check=True, capture_output=True)
                logger.info(f"Deleted existing secret: {secret_name}")

            # Create new secret
            create_cmd = ['kubectl', 'create', 'secret', 'generic', secret_name, '-n', namespace]

            for key, value in data.items():
                create_cmd.extend(['--from-literal', f'{key}={value}'])

            subprocess.run(create_cmd, check=True, capture_output=True)
            logger.info(f"Created/updated Kubernetes secret: {secret_name}")
            return True

        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create Kubernetes secret {secret_name}: {e}")
            return False

    def get_secret(self, secret_name: str, namespace: str = 'default') -> Dict[str, str]:
        """Get Kubernetes secret data"""
        try:
            cmd = ['kubectl', 'get', 'secret', secret_name, '-n', namespace, '-o', 'json']
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)

            secret_data = json.loads(result.stdout)
            decoded_data = {}

            if 'data' in secret_data:
                for key, encoded_value in secret_data['data'].items():
                    decoded_data[key] = base64.b64decode(encoded_value).decode('utf-8')

            return decoded_data

        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to get Kubernetes secret {secret_name}: {e}")
            return {}

class SecretSynchronizer:
    def __init__(self, project_id: str):
        self.secret_manager = SecretManager(project_id)
        self.k8s_manager = KubernetesSecretManager()
        self.project_id = project_id

    def sync_database_secrets(self) -> bool:
        """Sync database-related secrets from Secret Manager to Kubernetes"""
        try:
            logger.info("Syncing database secrets...")

            postgres_data = {
                'PGPASSWORD': self.secret_manager.get_secret('postgres-password'),
                'PGUSER': self.secret_manager.get_secret('postgres-user'),
                'PGHOST': self.secret_manager.get_secret('postgres-host'),
                'PGPORT': self.secret_manager.get_secret('postgres-port'),
                'PGDATABASE': self.secret_manager.get_secret('postgres-database')
            }

            # Create unified database secret
            success = self.k8s_manager.create_secret('database-secrets', postgres_data)

            # Also create the legacy pgpassword secret for backward compatibility
            pgpassword_data = {'PGPASSWORD': postgres_data['PGPASSWORD']}
            legacy_success = self.k8s_manager.create_secret('pgpassword', pgpassword_data)

            return success and legacy_success

        except Exception as e:
            logger.error(f"Failed to sync database secrets: {e}")
            return False

    def sync_redis_secrets(self) -> bool:
        """Sync Redis-related secrets from Secret Manager to Kubernetes"""
        try:
            logger.info("Syncing Redis secrets...")

            redis_data = {
                'REDIS_HOST': self.secret_manager.get_secret('redis-host'),
                'REDIS_PORT': self.secret_manager.get_secret('redis-port')
            }

            return self.k8s_manager.create_secret('redis-secrets', redis_data)

        except Exception as e:
            logger.error(f"Failed to sync Redis secrets: {e}")
            return False

    def sync_all_secrets(self) -> bool:
        """Sync all application secrets"""
        logger.info("Starting secret synchronization...")

        database_success = self.sync_database_secrets()
        redis_success = self.sync_redis_secrets()

        if database_success and redis_success:
            logger.info("✅ All secrets synchronized successfully!")
            return True
        else:
            logger.error("❌ Some secrets failed to synchronize")
            return False

    def validate_secrets(self) -> bool:
        """Validate that all required secrets exist in Secret Manager"""
        required_secrets = [
            'postgres-password',
            'postgres-user',
            'postgres-host',
            'postgres-port',
            'postgres-database',
            'redis-host',
            'redis-port'
        ]

        logger.info("Validating required secrets...")

        for secret_name in required_secrets:
            try:
                value = self.secret_manager.get_secret(secret_name)
                if not value:
                    logger.error(f"❌ Secret {secret_name} is empty")
                    return False
                logger.info(f"✅ Secret {secret_name} exists")
            except Exception:
                logger.error(f"❌ Secret {secret_name} not found")
                return False

        logger.info("✅ All required secrets validated")
        return True

def main():
    parser = argparse.ArgumentParser(description='Synchronize secrets from GCP Secret Manager to Kubernetes')
    parser.add_argument('--project-id', default='vschiavo-home', help='GCP Project ID')
    parser.add_argument('--validate-only', action='store_true', help='Only validate secrets exist')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    synchronizer = SecretSynchronizer(args.project_id)

    if args.validate_only:
        success = synchronizer.validate_secrets()
    else:
        # Validate first, then sync
        if synchronizer.validate_secrets():
            success = synchronizer.sync_all_secrets()
        else:
            logger.error("❌ Secret validation failed. Run manage-secrets.sh to create missing secrets.")
            success = False

    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
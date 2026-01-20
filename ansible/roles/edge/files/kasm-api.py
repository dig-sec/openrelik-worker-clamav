#!/usr/bin/env python3
"""
KASM Container Management API
Simple Flask API to manage KASM Docker containers
"""
import subprocess
import json
from flask import Flask, jsonify, request
from flask_cors import CORS
from functools import wraps

app = Flask(__name__)
CORS(app)

# Configuration
DOCKER_COMPOSE_PATH = "/opt/kasm"
ALLOWED_CONTAINERS = ["kasm-tor-browser", "kasm-forensic-osint", "kasm-proxy"]

def run_command(command, cwd=None):
    """Execute shell command and return result"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": "Command timed out",
            "returncode": -1
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }

def require_auth(f):
    """Simple authentication decorator"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # For now, we rely on nginx basic auth
        # Could add additional API key validation here
        return f(*args, **kwargs)
    return decorated_function

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "kasm-api"})

@app.route('/containers/status', methods=['GET'])
@require_auth
def container_status():
    """Get status of all KASM containers"""
    result = run_command(
        "docker ps --filter 'name=kasm-' --format '{{.Names}}|{{.Status}}|{{.State}}'",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if not result["success"]:
        return jsonify({
            "error": "Failed to get container status",
            "details": result["stderr"]
        }), 500
    
    try:
        containers = []
        for line in result["stdout"].strip().split('\n'):
            if line and '|' in line:
                parts = line.split('|')
                if len(parts) >= 3:
                    containers.append({
                        "name": parts[0],
                        "status": parts[1],
                        "state": parts[2]
                    })
        
        return jsonify({
            "containers": containers,
            "count": len(containers)
        })
    except Exception as e:
        return jsonify({
            "error": "Failed to parse container status",
            "details": str(e),
            "raw_output": result["stdout"]
        }), 500

@app.route('/containers/<container_name>/restart', methods=['POST'])
@require_auth
def restart_container(container_name):
    """Restart a specific KASM container"""
    if container_name not in ALLOWED_CONTAINERS:
        return jsonify({
            "error": "Container not allowed",
            "container": container_name,
            "allowed": ALLOWED_CONTAINERS
        }), 400
    
    result = run_command(
        f"docker-compose restart {container_name}",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if result["success"]:
        return jsonify({
            "success": True,
            "container": container_name,
            "action": "restart",
            "message": f"Container {container_name} restarted successfully"
        })
    else:
        return jsonify({
            "error": "Failed to restart container",
            "container": container_name,
            "details": result["stderr"]
        }), 500

@app.route('/containers/<container_name>/reset', methods=['POST'])
@require_auth
def reset_container(container_name):
    """Reset a container to clean state (stop, remove, recreate)"""
    if container_name not in ALLOWED_CONTAINERS:
        return jsonify({
            "error": "Container not allowed",
            "container": container_name,
            "allowed": ALLOWED_CONTAINERS
        }), 400
    
    # Stop and remove container
    stop_result = run_command(
        f"docker-compose stop {container_name}",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if not stop_result["success"]:
        return jsonify({
            "error": "Failed to stop container",
            "container": container_name,
            "details": stop_result["stderr"]
        }), 500
    
    remove_result = run_command(
        f"docker-compose rm -f {container_name}",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if not remove_result["success"]:
        return jsonify({
            "error": "Failed to remove container",
            "container": container_name,
            "details": remove_result["stderr"]
        }), 500
    
    # Recreate container
    create_result = run_command(
        f"docker-compose up -d {container_name}",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if create_result["success"]:
        return jsonify({
            "success": True,
            "container": container_name,
            "action": "reset",
            "message": f"Container {container_name} reset to clean state"
        })
    else:
        return jsonify({
            "error": "Failed to recreate container",
            "container": container_name,
            "details": create_result["stderr"]
        }), 500

@app.route('/containers/restart-all', methods=['POST'])
@require_auth
def restart_all_containers():
    """Restart all KASM containers"""
    result = run_command(
        "docker-compose restart",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if result["success"]:
        return jsonify({
            "success": True,
            "action": "restart-all",
            "message": "All KASM containers restarted successfully"
        })
    else:
        return jsonify({
            "error": "Failed to restart containers",
            "details": result["stderr"]
        }), 500

@app.route('/containers/reset-all', methods=['POST'])
@require_auth
def reset_all_containers():
    """Reset all KASM containers to clean state"""
    # Stop all containers
    down_result = run_command(
        "docker-compose down",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if not down_result["success"]:
        return jsonify({
            "error": "Failed to stop containers",
            "details": down_result["stderr"]
        }), 500
    
    # Recreate all containers
    up_result = run_command(
        "docker-compose up -d --force-recreate",
        cwd=DOCKER_COMPOSE_PATH
    )
    
    if up_result["success"]:
        return jsonify({
            "success": True,
            "action": "reset-all",
            "message": "All KASM containers reset to clean state"
        })
    else:
        return jsonify({
            "error": "Failed to recreate containers",
            "details": up_result["stderr"]
        }), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    # Run on localhost only (nginx will proxy)
    app.run(host='127.0.0.1', port=5001, debug=False)

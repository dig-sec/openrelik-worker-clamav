-- Pre-configure Guacamole connections for Utgard Lab
-- This runs after the schema initialization

-- Insert REMnux RDP connection
INSERT INTO guacamole_connection (connection_name, protocol, max_connections, max_connections_per_user) 
VALUES ('REMnux Analyst VM (RDP)', 'rdp', NULL, NULL);

SET @remnux_id = LAST_INSERT_ID();

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
VALUES
    (@remnux_id, 'hostname', '10.20.0.20'),
    (@remnux_id, 'port', '3389'),
    (@remnux_id, 'username', 'vagrant'),
    (@remnux_id, 'password', 'vagrant'),
    (@remnux_id, 'security', 'any'),
    (@remnux_id, 'ignore-cert', 'true'),
    (@remnux_id, 'create-drive-path', 'true'),
    (@remnux_id, 'enable-drive', 'true'),
    (@remnux_id, 'drive-name', 'shared'),
    (@remnux_id, 'drive-path', '/drive');

-- Insert OpenRelik SSH connection
INSERT INTO guacamole_connection (connection_name, protocol, max_connections, max_connections_per_user) 
VALUES ('OpenRelik Server (SSH)', 'ssh', NULL, NULL);

SET @openrelik_id = LAST_INSERT_ID();

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
VALUES
    (@openrelik_id, 'hostname', '10.20.0.30'),
    (@openrelik_id, 'port', '22'),
    (@openrelik_id, 'username', 'vagrant'),
    (@openrelik_id, 'password', 'vagrant');

-- Insert Firewall SSH connection
INSERT INTO guacamole_connection (connection_name, protocol, max_connections, max_connections_per_user) 
VALUES ('Firewall Gateway (SSH)', 'ssh', NULL, NULL);

SET @firewall_id = LAST_INSERT_ID();

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
VALUES
    (@firewall_id, 'hostname', '10.20.0.1'),
    (@firewall_id, 'port', '22'),
    (@firewall_id, 'username', 'vagrant'),
    (@firewall_id, 'password', 'vagrant');

-- Insert Neko VM SSH connection
INSERT INTO guacamole_connection (connection_name, protocol, max_connections, max_connections_per_user) 
VALUES ('Neko Browser VM (SSH)', 'ssh', NULL, NULL);

SET @neko_id = LAST_INSERT_ID();

INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
VALUES
    (@neko_id, 'hostname', '10.20.0.40'),
    (@neko_id, 'port', '22'),
    (@neko_id, 'username', 'vagrant'),
    (@neko_id, 'password', 'vagrant');

-- Grant access to default admin user (guacadmin)
INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
SELECT 
    (SELECT entity_id FROM guacamole_entity WHERE name = 'guacadmin' AND type = 'USER'),
    connection_id,
    'READ'
FROM guacamole_connection
WHERE connection_name IN ('REMnux Analyst VM (RDP)', 'OpenRelik Server (SSH)', 'Firewall Gateway (SSH)', 'Neko Browser VM (SSH)');

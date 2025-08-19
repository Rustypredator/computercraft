<?php

require_once 'secret.php';
require_once 'database.php';

class Api
{
    public function __construct()
    {
        //
    }

    private function validateSession(): array|bool
    {
        // Get required data:
        $body = file_get_contents('php://input');
        $data = json_decode($body, true);
        // Check if fields are populated:
        $requiredFields = ['playerName', 'playerUUID', 'timestamp', 'hits', 'hash'];
        foreach ($requiredFields as $field) {
            if (!isset($data[$field])) {
                http_response_code(400);
                echo json_encode(['error' => "Missing required field: $field"]);
                var_dump($data);
                return false;
            }
        }
        // All fields are populated.
        // Clean up playername:
        $data['playerName'] = trim($data['playerName']); //whitespace
        $data['playerName'] = preg_replace('/(\[.*?\])/', '', $data['playerName']); // remove anything that is in [] brackets (prefix etc.)
        // Validate hash:
        $secret = new Secret();
        if (!$secret->validateHash($data['timestamp'], $data['hash'])) {
            http_response_code(403);
            echo json_encode(['error' => 'Invalid hash']);
            return false;
        }
        // Hash is valid.
        return $data;
    }

    public function saveSession(): bool
    {
        $data = $this->validateSession();
        if (!$data) {
            return false;
        }
        // Save the session data:
        $db = new Database();
        $db->addSession($data['playerUUID'], $data['playerName'], $data['timestamp'], $data['hits']);

        return true;
    }
}
<?php

function db_createTable(): void
{
    $db = new SQLite3('shootingrange.db');
    $db->exec("CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY, playerName TEXT, timestamp TEXT, hits TEXT)");
}

function db_connect(): SQLite3
{
    $db = new SQLite3('shootingrange.db');
    if ($db) {
        // Make sure the table exists
        db_createTable();
        return $db;
    }
    throw new Exception('Failed to connect to database');
}

function api_save_validate(): array|bool
{
    // Validate save request is complete:
    // Required fields: playerName, timestamp, hits, hash
    $body = file_get_contents('php://input');
    $data = json_decode($body, true);
    if (!isset($data['playerName']) || !isset($data['timestamp']) || !isset($data['hits']) || !isset($data['hash'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid request']);
        return false;
    }
    $playername = $data['playerName'];
    $timestamp = $data['timestamp'];
    $hits = $data['hits'];
    $clientHash = $data['hash'];
    error_log('Received: ' . json_encode($data));
    // Create secret hash using provided timestamp
    $secretFile = fopen('secret.txt', 'r');
    $serverSecret = fread($secretFile, filesize('secret.txt'));
    fclose($secretFile);
    $timestampInt = intval($timestamp);
    $serverTime = time();
    if (abs($serverTime - $timestampInt) > 5) {
        http_response_code(400);
        echo json_encode(['error' => 'Timestamp out of range']);
        return false;
    }
    $expectedHash = hash('sha256', $timestampInt . $serverSecret);
    error_log('Expected hash: ' . $expectedHash);
    if ($clientHash !== $expectedHash) {
        error_log('Hash mismatch.');
        http_response_code(403);
        echo json_encode(['error' => 'Invalid hash']);
        return false;
    }
    return $data;
}

function api_save(): bool
{
    $data = api_save_validate();
    if (!$data) {
        return false;
    }
    // Clean up playername:
    $playername = trim($data['playerName']); //whitespace
    $playername = preg_replace('/(\[.*?\])/', '', $playername); // remove anything that is in [] brackets (prefix etc.)
    // Save session to db:
    db_createTable();
    $db = db_connect();
    $stmt = $db->prepare("INSERT INTO sessions (playerName, timestamp, hits) VALUES (:playerName, :timestamp, :hits)");
    $stmt->bindValue(':playerName', $playername, SQLITE3_TEXT);
    $stmt->bindValue(':timestamp', $data['timestamp'], SQLITE3_TEXT);
    $stmt->bindValue(':hits', json_encode($data['hits']), SQLITE3_TEXT);
    $result = (bool)$stmt->execute();
    if (!$result) {
        return false;
    }
    return true;
}

function index_dump(): void
{
    // This function is used to dump the current state of the shooting range.
    // It will return a JSON object with all sessions.
    $db = db_connect();
    $results = $db->query("SELECT * FROM sessions");
    $sessions = [];
    while ($row = $results->fetchArray(SQLITE3_ASSOC)) {
        $sessions[] = $row;
    }
    echo json_encode($sessions);
}

function router(): void
{
    // get request path
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    $method = $_SERVER['REQUEST_METHOD'];
    // route request
    if ($method === 'POST' && $path === '/api/save') {
        api_save();
    } elseif ($method === 'GET' && $path === '/') {
        index_dump();
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Not found']);
    }
}

router();
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shooting Range Scoreboard</title>
    <style>
        table {
            border-collapse: collapse;
            width: 100%;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
</head>
<body>

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

function htmlHeader($title = 'Scoreboard'): void
{

    echo "<a href=\"/\">Home</a>";

    echo "<h1>Scoreboard</h1>";
    echo "<p>Welcome to the shooting range scoreboard!</p>";

    echo "<h2>" . htmlspecialchars($title) . "</h2>";

}

function calculateTotalScore($hits): int
{
    $total = 0;
    foreach ($hits as $hit) {
        $total += $hit['strength'];
    }
    return $total;
}

function calculateAverageScore($hits): float
{
    $total = calculateTotalScore($hits);
    $count = count($hits);
    return $count > 0 ? $total / $count : 0;
}

function calculateAverageTimeBetweenHits($hits): float
{
    $totalTime = 0;
    $count = 0;
    $previousHitTimestamp = null;
    foreach ($hits as $hit) {
        if ($previousHitTimestamp !== null) {
            $timeDiff = $previousHitTimestamp - $hit['time'];
            $totalTime += $timeDiff;
            $count++;
        }
        $previousHitTimestamp = $hit['time'];
    }
    return $count > 0 ? $totalTime / $count : 0;
}

function index_table(): void
{
    $db = db_connect();
    $data = $db->query("SELECT * FROM sessions");
    $sessions = [];
    while ($row = $data->fetchArray(SQLITE3_ASSOC)) {
        $sessions[] = $row;
    }
    if (empty($sessions)) {
        echo "<p>No sessions found.</p>";
        return;
    }

    echo "<table>";
    echo "
    <tr>
        <th>Player</th>
        <th>Timestamp</th>
        <th>Hits</th>
        <th>Total Score</th>
        <th>Average Score</th>
        <th>Average Time Between Hits</th>
        <th>Actions</th>
    </tr>";
    foreach ($sessions as $session) {
        $hits = json_decode($session['hits'], true);
        echo "<tr>";
        echo "<td><a href=\"/player/" . htmlspecialchars($session['playerName']) . "\">" . htmlspecialchars($session['playerName']) . "</a></td>";
        echo "<td>" . htmlspecialchars(date('Y-m-d H:i:s', $session['timestamp'])) . "</td>";
        echo "<td>" . htmlspecialchars(count($hits ?? []) ?? 0) . "</td>";
        echo "<td>" . htmlspecialchars(calculateTotalScore($hits)) . "</td>";
        echo "<td>" . htmlspecialchars(calculateAverageScore($hits)) . "</td>";
        echo "<td>" . htmlspecialchars(calculateAverageTimeBetweenHits($hits)) . "</td>";
        echo "
        <td>
            <a href=\"/session/" . htmlspecialchars($session['id']) . "\">Details</a>
        </td>";
        echo "</tr>";
    }
    echo "</table>";
}

function playerTable($playerName): void
{
    $db = db_connect();
    $data = $db->prepare("SELECT * FROM sessions WHERE playerName = :playerName");
    $data->bindValue(':playerName', $playerName, SQLITE3_TEXT);
    $sessions = [];
    $result = $data->execute();
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $sessions[] = $row;
    }
    if (empty($sessions)) {
        echo "<p>No sessions found.</p>";
        return;
    }

    echo "<table>";
    echo "
    <tr>
        <th>Timestamp</th>
        <th>Hits</th>
        <th>Total Score</th>
        <th>Average Score</th>
        <th>Average Time Between Hits</th>
        <th>Actions</th>
    </tr>
    ";
    foreach ($sessions as $session) {
        $hits = json_decode($session['hits'], true);
        echo "<tr>";
        echo "<td>" . htmlspecialchars(date('Y-m-d H:i:s', $session['timestamp'])) . "</td>";
        echo "<td>" . htmlspecialchars(count($hits ?? []) ?? 0) . "</td>";
        echo "<td>" . htmlspecialchars(calculateTotalScore($hits)) . "</td>";
        echo "<td>" . htmlspecialchars(calculateAverageScore($hits)) . "</td>";
        echo "<td>" . htmlspecialchars(calculateAverageTimeBetweenHits($hits)) . "</td>";
        echo "
        <td>
            <a href=\"/session/" . htmlspecialchars($session['id']) . "\">Details</a>
        </td>";
        echo "</tr>";
    }
}

function detailTable($sessionId): void
{
    $db = db_connect();
    $data = $db->prepare("SELECT * FROM sessions WHERE id = :sessionId");
    $data->bindValue(':sessionId', $sessionId, SQLITE3_INTEGER);
    $result = $data->execute();
    $session = $result->fetchArray(SQLITE3_ASSOC);
    if (!$session) {
        echo "<p>No session found with ID: " . htmlspecialchars($sessionId) . "</p>";
        return;
    }

    echo "<table>";
    echo "
    <tr>
        <th>HitNr</th>
        <th>Strength</th>
        <th>Time</th>
        <th>Position</th>
    </tr>
    ";
    $counter = 1;
    $hits = json_decode($session['hits'], true);
    foreach ($hits as $hit) {
        echo "
        <tr>
            <td>" . htmlspecialchars($counter) . "</td>
            <td>" . htmlspecialchars($hit['strength']) . "</td>
            <td>" . htmlspecialchars($hit['time']) . "</td>
            <td>" . htmlspecialchars(json_encode($hit['position'])) . "</td>
        </tr>
        ";
        $counter++;
    }
    echo "</table>";
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
        htmlHeader("All Sessions");
        index_table();
    } elseif ($method === 'GET' && preg_match('/^\/player\/(.+)$/', $path, $matches)) {
        htmlHeader("Player: " . htmlspecialchars($matches[1]));
        playerTable($matches[1]);
    } elseif ($method === 'GET' && preg_match('/^\/session\/(.+)$/', $path, $matches)) {
        htmlHeader("Session: " . htmlspecialchars($matches[1]));
        detailTable($matches[1]);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Not found']);
    }
}

router();
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shooting Range Scoreboard</title>
    <style>
        html {
            background-color: #181a1b;
            color: #e8e6e3;
            font-family: monospace;
        }
        table {
            border-collapse: collapse;
            width: 100%;
        }
        th, td {
            border: 1px solid #545b5e;
            padding: 8px;
        }
        th {
            background-color: #2c2c2cff;
        }
    </style>
</head>
<body>

<?php

function db_createTable(): void
{
    $db = new SQLite3('shootingrange.db');
    $db->exec("CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY, playerName TEXT, playerUUID TEXT, timestamp TEXT)");
    $db->exec("CREATE TABLE IF NOT EXISTS hits (id INTEGER PRIMARY KEY, sessionId INTEGER, score INTEGER, time TEXT, position TEXT, FOREIGN KEY(sessionId) REFERENCES sessions(id))");
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
    if (!isset($data['playerName']) || !isset($data['playerUUID']) || !isset($data['timestamp']) || !isset($data['hits']) || !isset($data['hash'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid request']);
        return false;
    }
    $playername = $data['playerName'];
    $playerUUID = $data['playerUUID'];
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
    $stmt = $db->prepare("INSERT INTO sessions (playerName, timestamp) VALUES (:playerName, :timestamp)");
    $stmt->bindValue(':playerName', $playername, SQLITE3_TEXT);
    $stmt->bindValue(':timestamp', $data['timestamp'], SQLITE3_TEXT);
    $result = (bool)$stmt->execute();
    if (!$result) {
        return false;
    }
    // get id of just inserted session:
    $sessionId = $db->lastInsertRowID();

    // Save hits to db:
    foreach ($data['hits'] as $hit) {
        $stmt = $db->prepare("INSERT INTO hits (sessionId, score, time, position) VALUES (:sessionId, :score, :time, :position)");
        $stmt->bindValue(':sessionId', $sessionId, SQLITE3_INTEGER);
        $stmt->bindValue(':score', $hit['strength'], SQLITE3_INTEGER);
        $stmt->bindValue(':time', $hit['time'], SQLITE3_TEXT);
        $stmt->bindValue(':position', json_encode($hit['position']), SQLITE3_TEXT);
        $stmt->execute();
    }
    return true;
}

function htmlHeader($title = 'Scoreboard'): void
{
    echo "<a href=\"/\">All Sessions</a> | <a href=\"/?sort=score\">All Sessions (sorted by total Score)</a> | <a href=\"/?sort=average\">All Sessions (sorted by average Score)</a>";

    echo "<h1>Scoreboard</h1>";
    echo "<p>Welcome to the shooting range scoreboard!</p>";

    echo "<h2>" . htmlspecialchars($title) . "</h2>";
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
    // get sorting rule
    if (!empty($_GET['sort'])) {
        $sort = $_GET['sort'];
        if ($sort === 'score') {
            $data = $db->query("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions JOIN hits ON sessions.id = hits.sessionId GROUP BY sessions.id ORDER BY totalScore DESC");
        } elseif ($sort === 'average') {
            $data = $db->query("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions JOIN hits ON sessions.id = hits.sessionId GROUP BY sessions.id ORDER BY averageScore DESC");
        }
    } else {
        $data = $db->query("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions JOIN hits ON sessions.id = hits.sessionId GROUP BY sessions.id");
    }
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
        <th>Total Score</th>
        <th>Average Score</th>
        <th>Actions</th>
    </tr>";
    foreach ($sessions as $session) {
        echo "<tr>";
        echo "<td><a href=\"/player/" . htmlspecialchars($session['playerUUID']) . "\">" . htmlspecialchars($session['playerName']) . "</a></td>";
        echo "<td>" . htmlspecialchars(date('Y-m-d H:i:s', $session['timestamp'])) . "</td>";
        echo "<td>" . htmlspecialchars($session['totalScore']) . "</td>";
        echo "<td>" . htmlspecialchars($session['averageScore']) . "</td>";
        echo "
        <td>
            <a href=\"/session/" . htmlspecialchars($session['id']) . "\">Details</a>
        </td>";
        echo "</tr>";
    }
    echo "</table>";
}

function playerTable($playerUUID): void
{
    $db = db_connect();
    if (!empty($_GET['sort'])) {
        $sort = $_GET['sort'];
        if ($sort === 'score') {
            $data = $db->prepare("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE playerUUID = :playerUUID GROUP BY sessions.id ORDER BY totalScore DESC");
        } elseif ($sort === 'average') {
            $data = $db->prepare("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE playerUUID = :playerUUID GROUP BY sessions.id ORDER BY averageScore DESC");
        }
    } else {
        $data = $db->prepare("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE playerUUID = :playerUUID GROUP BY sessions.id");
    }
    $data->bindValue(':playerUUID', $playerUUID, SQLITE3_TEXT);
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
        <th>Total Score</th>
        <th>Average Score</th>
        <th>Actions</th>
    </tr>
    ";
    foreach ($sessions as $session) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars(date('Y-m-d H:i:s', $session['timestamp'])) . "</td>";
        echo "<td>" . htmlspecialchars($session['totalScore']) . "</td>";
        echo "<td>" . htmlspecialchars($session['averageScore']) . "</td>";
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
    $sessionData = $db->prepare("SELECT sessions.*, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE sessions.id = :sessionId");
    $sessionData->bindValue(':sessionId', $sessionId, SQLITE3_INTEGER);
    $result = $sessionData->execute();
    $session = $result->fetchArray(SQLITE3_ASSOC);
    if (!$session) {
        echo "<p>No session found with ID: " . htmlspecialchars($sessionId) . "</p>";
        return;
    }
    // get hits:
    $hitsData = $db->prepare("SELECT * FROM hits WHERE sessionId = :sessionId");
    $hitsData->bindValue(':sessionId', $sessionId, SQLITE3_INTEGER);
    $hitsResult = $hitsData->execute();
    $hits = [];
    while ($hit = $hitsResult->fetchArray(SQLITE3_ASSOC)) {
        $hits[] = $hit;
    }

    echo "<h2>Session Details</h2>";
    echo "Amount of Hits: " . count($hits) . "<br>";
    echo "Total Score: " . htmlspecialchars($session['totalScore']) . "<br>";
    echo "Average Score: " . htmlspecialchars($session['averageScore']) . "<br>";

    echo "<table>";
    echo "
    <tr>
        <th>HitID</th>
        <th>Score</th>
        <th>Time</th>
        <th>Position</th>
    </tr>
    ";
    $counter = 1;
    foreach ($hits as $hit) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($hit['id']) . "</td>";
        echo "<td>" . htmlspecialchars($hit['score']) . "</td>";
        echo "<td>" . htmlspecialchars($hit['time']) . "</td>";
        echo "<td>" . htmlspecialchars($hit['position']) . "</td>";
        echo "</tr>";
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
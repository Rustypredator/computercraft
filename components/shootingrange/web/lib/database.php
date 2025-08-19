<?php

Class Database {
    private $db;

    public function __construct() {
        $this->db = new SQLite3('../storage/shootingrange.db');
        if ($this->db) {
            $this->createStructure();
        } else {
            throw new Exception('Failed to connect to database');
        }
    }

    private function createStructure()
    {
        $this->db->exec("CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY, playerName TEXT, playerUUID TEXT, timestamp TEXT)");
        $this->db->exec("CREATE TABLE IF NOT EXISTS hits (id INTEGER PRIMARY KEY, sessionId INTEGER, score INTEGER, time TEXT, position TEXT, FOREIGN KEY(sessionId) REFERENCES sessions(id))");
    }

    public function addSession($playerUUID, $playerName, $timestamp, $hits)
    {
        $result = $this->db->query("INSERT INTO sessions (playerUUID, playerName, timestamp) VALUES ('$playerUUID', '$playerName', '$timestamp')");
        if ($result) {
            $sessionId = $this->db->lastInsertRowID();
            foreach ($hits as $hit) {
                $this->db->query("INSERT INTO hits (sessionId, score, time, position) VALUES ($sessionId, {$hit['strength']}, '{$hit['time']}', '{$hit['number']}')");
            }
            return true;
        }
        return false;
    }

    public function getAllSessions($sortBy = 'timestamp'): array
    {
        $orderBy = match ($sortBy) {
            'score' => 'totalScore',
            'average' => 'averageScore',
            default => 'timestamp',
        };
        $result = $this->db->query("SELECT sessions.*, COUNT(hits.id) as hitCount, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId GROUP BY sessions.id ORDER BY $orderBy DESC");
        $sessions = [];
        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $sessions[] = $row;
        }
        return $sessions;
    }

    public function getDistinctPlayers(): array
    {
        $result = $this->db->query("SELECT DISTINCT playerUUID FROM sessions");
        $players = [];
        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            // get the playerName:
            $playerName = $this->db->query("SELECT playerName FROM sessions WHERE playerUUID = '{$row['playerUUID']}' LIMIT 1")->fetchArray(SQLITE3_ASSOC)['playerName'] ?? 'Unknown';
            $players[] = ['playerUUID' => $row['playerUUID'], 'playerName' => $playerName];
        }
        return $players;
    }

    public function getPlayerSessions($playerUUID, $sortBy = 'timestamp'): array
    {
        $orderBy = match ($sortBy) {
            'score' => 'totalScore',
            'average' => 'averageScore',
            default => 'timestamp',
        };
        $result = $this->db->query("SELECT sessions.*, COUNT(hits.id) as hitCount, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE sessions.playerUUID = '$playerUUID' GROUP BY sessions.id ORDER BY $orderBy DESC");
        $sessions = [];
        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $sessions[] = $row;
        }
        return $sessions;
    }

    public function getSessionDetails($sessionId): array
    {
        $result = $this->db->query("SELECT sessions.*, COUNT(hits.id) as hitCount, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE sessions.id = $sessionId");
        $session = $result->fetchArray(SQLITE3_ASSOC);
        $result = $this->db->query("SELECT * FROM hits WHERE sessionId = $sessionId ORDER BY time ASC");
        $hits = [];
        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $hits[] = $row;
        }
        return ['session' => $session, 'hits' => $hits];
    }

    public function getHighscoreSession(): array
    {
        $result = $this->db->query("SELECT sessions.*, COUNT(hits.id) as hitCount, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId GROUP BY sessions.id ORDER BY totalScore DESC LIMIT 1");
        return $result->fetchArray(SQLITE3_ASSOC);
    }

    public function getAverageScore(): float
    {
        $result = $this->db->query("SELECT AVG(totalScore) as averageScore FROM (SELECT SUM(score) as totalScore FROM hits GROUP BY sessionId)");
        $row = $result->fetchArray(SQLITE3_ASSOC);
        return (float)($row['averageScore'] ?? 0);
    }

    public function getTodaysSessions(): array
    {
        // Return only games that have the same DAY as today.
        // Timestamp is a UNIX timestamp.
        $today = (new DateTime())->setTime(0, 0, 0);
        $tomorrow = (new DateTime())->setTime(0, 0, 0)->modify('+1 day');
        $result = $this->db->query("SELECT sessions.*, COUNT(hits.id) as hitCount, SUM(hits.score) as totalScore, AVG(hits.score) as averageScore FROM sessions LEFT JOIN hits ON sessions.id = hits.sessionId WHERE sessions.timestamp >= {$today->getTimestamp()} AND sessions.timestamp < {$tomorrow->getTimestamp()} GROUP BY sessions.id");
        $games = [];
        while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
            $games[] = $row;
        }
        return $games;
    }
}
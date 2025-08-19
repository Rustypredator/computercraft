<?php

$baseDir = dirname(__FILE__, 2);

require_once $baseDir . '/lib/database.php';
require_once $baseDir . '/lib/api.php';
require_once $baseDir . '/lib/render.php';

function router(): void
{
    // get request path
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    // Trim php file from path, example: /new.php/sessions => /sessions
    $path = preg_replace('/^\/new\.php/', '', $path);
    $method = $_SERVER['REQUEST_METHOD'];
    // route request
    if ($method === 'POST' && $path === '/api/save') {
        $a = new Api();
        $a->saveSession();
    } elseif ($method === 'GET' && $path === '/') {
        $db = new Database();
        $sessions = $db->getAllSessions();
        $players = $db->getDistinctPlayers();
        $highScore = $db->getHighscoreSession();
        $averageScore = $db->getAverageScore();
        $todaysSessions = $db->getTodaysSessions();
        Render::view('home', ['sessions' => $sessions, 'players' => $players, 'highScore' => $highScore, 'averageScore' => $averageScore, 'todaysSessions' => $todaysSessions]);
    } elseif ($method === 'GET' && $path === '/sessions') {
        $db = new Database();
        $sessions = $db->getAllSessions();
        Render::view('sessions', ['title' => 'Sessions', 'sessions' => $sessions]);
    } elseif ($method === 'GET' && preg_match('/^\/player\/(.+)$/', $path, $matches)) {
        $db = new Database();
        $sessions = $db->getPlayerSessions($matches[1]);
        Render::view('player', ['playerUUID' => $matches[1], 'sessions' => $sessions]);
    } elseif ($method === 'GET' && preg_match('/^\/session\/(.+)$/', $path, $matches)) {
        $db = new Database();
        $session = $db->getSessionDetails($matches[1]);
        Render::view('session', ['sessionID' => $matches[1], 'session' => $session]);
    } elseif ($method === 'GET' && $path === '/players') {
        $db = new Database();
        $players = $db->getDistinctPlayers();
        Render::view('players', ['title' => 'Players', 'players' => $players]);
    } else {
        Render::code(404);
    }
}

router();
<?php

class Secret
{
    public function __construct()
    {
        $this->secret = trim(file_get_contents('../storage/secret.txt'));
    }

    public function validateHash($timestamp, $hash): bool
    {
        $expectedHash = hash('sha256', $timestamp.$this->secret);
        return hash_equals($expectedHash, $hash);
    }
}
<?php

class Render
{
    public static function view($path, $data = [])
    {
        // Path can contain dots, which need to be replaced with slashes.
        $path = str_replace('.', '/', $path);
        // check if the file exists in the "storage/views" directory.
        $file = __DIR__ . '/../storage/views/' . $path . '.phtml';
        if (file_exists($file)) {
            // Prepare data to be included in files:
            extract($data);
            // Render head component:
            include __DIR__ . '/../storage/views/components/head.phtml';
            // Render the requested view:
            include $file;
            // Render foot component:
            include __DIR__ . '/../storage/views/components/foot.phtml';
        } else {
            self::code(404);
        }
    }

    public static function code($code)
    {
        http_response_code($code);
        // Optionally render a view for the error code
        if ($code === 404) {
            self::view('error.404', []);
        } elseif ($code === 500) {
            self::view('error.500', []);
        }
    }
}
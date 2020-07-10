<?php
    $ts = gmdate("D, d M Y H:i:s", time() + 2 * 3600) . " GMT";
    header("Expires: $ts");
    header("Pragma: cache");
    header("Cache-Control: max-age=$seconds_to_cache");
    header("Content-type: image/jpeg");
 
    $steam_api_key = "YOUR STEAM API KEY GOES HERE";
    $steamurl = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s";
 
    if(isset($_GET["steamid"]))
    {
        $steamid = $_GET["steamid"];
        $json_api = file_get_contents(sprintf($steamurl, $steam_api_key, $steamid));
        $avatar_url = json_decode($json_api)->response->players[0]->avatarfull;
        $avatar_raw = null;
        $filename = sprintf("avatars/%s.png", $steamid);
 
        if(file_exists($filename))
        {
            if (time()-filemtime($filename) > 2 * 3600)
            {
                unlink($filename);
                $avatar_raw = file_get_contents($avatar_url);
 
                file_put_contents($filename, $avatar_raw);
            }
            else
                $avatar_raw = file_get_contents($filename);
        }
        else
        {
            $avatar_raw = file_get_contents($avatar_url);
            file_put_contents($filename, $avatar_raw);
        }
       
        $skin = imagecreatefromstring($avatar_raw);
 
        ob_clean();
        imagejpeg($skin, null, 100);
    } 
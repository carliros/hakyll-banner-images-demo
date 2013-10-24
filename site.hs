--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Control.Applicative (empty, (<$>))
import           Control.Monad
import           Data.List
import           Data.Monoid (mappend, mconcat, mempty)
import           Hakyll
import           System.FilePath

--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    -- Compile templates.
    match "templates/*" $ compile templateCompiler

    -- Create small, medium and full versions of the banner.png image in your
    -- post directories.
    let (postImages, postImageField) = imageProcessor "posts/*/banner.png"
                                         [ ("small" , Just (200,100))
                                         , ("medium", Just (600,300))
                                         , ("full"  , Nothing)
                                         ]

    -- Use the generated rules to process the images.
    postImages

    -- Use the generated context to display the images.
    match "posts/*/index.md" $ do
        route $ setExtension "html"
        compile $ do
          -- Use the image field in your post contexts.
          let ctx = postImageField `mappend`
                    postContext

          pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"     ctx
            >>= loadAndApplyTemplate "templates/_default.html" ctx
            >>= relativizeUrls

--------------------------------------------------------------------------------
postContext :: Context String
postContext = mconcat
    [ modificationTimeField "mtime" "%U"
    , dateField "date" "%B %e, %Y"
    , dateField "datetime" "%Y-%m-%d"
    , defaultContext
    ]

--------------------------------------------------------------------------------
-- Image processing
--------------------------------------------------------------------------------

type ImageProcessing = [(String, Maybe (Int, Int))]

-- | Process image files according to a specification.
--
-- The 'Rules' and 'Context'  returned can be used to output and 
imageProcessor :: Pattern -- ^ Images to process.
               -> ImageProcessing -- ^ Processing instructions.
               -> (Rules (), Context a)
imageProcessor pat procs = let field = imageField pat procs 
                               rules = imageRules pat procs
                            in (rules, field)

-- | Generate 'Rules' to process images.
imageRules :: Pattern -- ^ Pattern to identify images.
           -> ImageProcessing -- ^ Versions to generate.
           -> Rules ()
imageRules pat procs = match pat $ do
  sequence_ $ map processImage procs
  where
    imageRoute name ident = let path = toFilePath ident
                                base = takeFileName path
                                name' = name ++ "-" ++ base
                            in replaceFileName path name'
    -- Process an image with no instructions.
    processImage (name, Nothing) = version name $ do
        route $ customRoute (imageRoute name)
        compile $ copyFileCompiler
    -- Process with scale and crop instructions.
    processImage (name, Just (x,y)) = version name $ do
        route $ customRoute (imageRoute name)
        let cmd = "convert"
        let args = [ "-"
                   , "-resize"
                   , concat [show x, "x", show y, "^"]
                   , "-gravity"
                   , "Center"
                   , "-crop"
                   , concat [show x, "x", show y, "+0+0"]
                   , "+repage"
                   , "-"
                   ]
        compile $ getResourceLBS >>= withItemBody (unixFilterLBS cmd args)

-- | Add image versions associated with an 'Item' to the context.
--
-- Variables defined
imageField :: Pattern -- ^ Pattern to identify images.
           -> ImageProcessing -- ^ Versions to generate.
           -> Context a
imageField pat procs = mconcat $ map (fff pat) procs
  where
    idPath = toFilePath . flip fromCaptures (map show [1..])
    fff p (name, _) = let imgpath = idPath p
                          imgfile = takeFileName imgpath
                          key = (takeBaseName imgpath) ++ "-" ++ name
                      in field key $ \item ->
                          let path = toFilePath $ itemIdentifier item
                              (dir, file) = splitFileName path
                              path' = combine dir imgfile
                              imgid = setVersion (Just name) $ fromFilePath path' 
                          in do
                            mroute <- getRoute imgid
                            case mroute of
                              Nothing -> empty
                              Just route -> return $ "<img src='" ++ (toUrl route) ++ "'>"

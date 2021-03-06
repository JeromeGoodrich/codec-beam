module Codec.Beam.Bytes (encode) where


import Data.Bits ((.|.), (.&.))
import Data.Word (Word8)
import qualified Data.Bits as Bits


encode :: Word8 -> Int -> [Word8]
encode tag n
  | tag >= 7 = extBytes tag n
  | n < 0 = manyBytes tag (negative n [])
  | n < 0x10 = oneByte tag n
  | n < 0x800 = twoBytes tag n
  | otherwise = manyBytes tag (positive n [])

extBytes :: Word8 -> Int -> [Word8]
extBytes tag n =
  [ Bits.xor top4 convertedTag, 0 ]

  where
    convertedTag =
     Bits.shiftL (tag - 7) 4 .|. 7

    top4 =
      Bits.shiftL (fromIntegral n) 4


oneByte :: Word8 -> Int -> [Word8]
oneByte tag n =
  [ top4 .|. tag ]

  where
    top4 =
      Bits.shiftL (fromIntegral n) 4


twoBytes :: Word8 -> Int -> [Word8]
twoBytes tag n =
  [ top3 .|. continuation .|. tag, bottom8 ]

  where
    top3 =
      fromIntegral $ Bits.shiftR n 3 .&. 0xE0

    bottom8 =
      fromIntegral n

    continuation =
      0x8


manyBytes :: Word8 -> [Word8] -> [Word8]
manyBytes tag bytes =
  if count <= 8 then
    (packedCount .|. continuation .|. tag) : bytes

  else
    (nested .|. tag) : encode 0 (count - 9) ++ bytes

  where
    count =
      length bytes

    packedCount =
      fromIntegral $ Bits.shiftL (count - 2) 5

    continuation =
      0x18

    nested =
      0xF8


negative :: Int -> [Word8] -> [Word8]
negative n bytes =
  case ( n, bytes ) of
    ( -1, first : _ : _ ) | first > 0x7F ->
      bytes

    _ ->
      withBottom8 negative n bytes


positive :: Int -> [Word8] -> [Word8]
positive n bytes =
  case ( n, bytes ) of
    ( 0, first : _ ) | first < 0x80 ->
      bytes

    _ ->
      withBottom8 positive n bytes


withBottom8 :: (Int -> [Word8] -> a) -> Int -> [Word8] -> a
{-# INLINE withBottom8 #-}
withBottom8 f n bytes =
  f (Bits.shiftR n 8) (fromIntegral n : bytes)

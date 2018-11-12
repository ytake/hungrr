<?hh 

namespace Ytake\Hhttp;

use type Psr\Http\Message\StreamInterface;
use namespace HH\Lib\{Str};

use function array_map;
use function array_values;

trait MessageTrait {

  private Map<string, varray<string>> $headers = Map{};
  private Map<string, string> $headerNames = Map{};

  private string $protocol = '1.1';

  private ?StreamInterface $stream;

  private function setHeaders(Map<string, varray<string>> $originalHeaders) : void {
    $headerNames = $headers = [];
    foreach ($originalHeaders as $header => $value) {
      $value = $this->filterHeaderValue($value);
      $this->assertHeader($header);
      $headerNames[Str\lowercase($header)] = $header;
      $headers[$header] = $value;
    }
    $this->headerNames = new Map($headerNames);
    $this->headers = new Map($headers);
  }

  private function getStream(mixed $stream, string $modeIfNotInstance) : StreamInterface {
    if ($stream is StreamInterface) {
      return $stream;
    }
    if (!$stream is string && !$stream is resource) {
      throw new Exception\InvalidArgumentException(
        'Stream must be a string stream resource identifier, '
        . 'an actual stream resource, '
        . 'or a Psr\Http\Message\StreamInterface implementation'
      );
    }
    return new Stream($stream, $modeIfNotInstance);
  }

  private function assertHeader(string $name) : void {
    AssertHeader::assertValidName($name);
  }

  private function filterHeaderValue(mixed $values): varray<string> {
    if (! is_array($values)) {
      $values = [$values];
    }
    if ([] === $values) {
      throw new Exception\InvalidArgumentException(
        'Invalid header value: must be a string or array of strings; '
        . 'cannot be an empty array'
      );
    }
    return array_map(($value) ==> {
      AssertHeader::assertValid($value);
      return (string) $value;
    }, array_values($values));
  }

  <<__Rx>>
  public function getProtocolVersion() {
    return $this->protocol;
  }

  public function withProtocolVersion($version) {
    if ($this->protocol === $version) {
      return $this;
    }
    $new = clone $this;
    $new->protocol = $version;
    return $new;
  }

  public function getHeaders() {
    return $this->headers->toArray();
  }

  public function hasHeader($header) {
    return $this->headerNames->contains(Str\lowercase($header));
  }

  public function getHeader($header) {
    $header = Str\lowercase($header);
    if (!$this->headerNames->contains($header)) {
      return [];
    }
    return $this->headers->at($this->headerNames->at($header));
  }

  public function getHeaderLine($header) {
    return Str\join($this->getHeader($header), ', ');
  }

  public function withHeader($header, $value) {
    $value = $this->validateAndTrimHeader($header, $value);
    $normalized = Str\lowercase($header);
    $new = clone $this;
    if ($this->headerNames->contains($normalized)) {
      $new->headers->remove($this->headerNames->at($normalized));
    }
    $new->headerNames->add(Pair{$normalized, $header});
    $new->headers->add(Pair{$header, $value});
    return $new;
  }

  public function withAddedHeader($name, $value) {
    if (!$name is string || '' === $name) {
      throw new \InvalidArgumentException('Header name must be an RFC 7230 compatible string.');
    }
    $new = clone $this;
    $new = $new->withHeader($name, $value);
    return $new;
  }

  public function withoutHeader($header) {
    $normalized = Str\lowercase($header);
    if (!$this->headerNames->contains($normalized)) {
      return $this;
    }
    $header = $this->headerNames->at($normalized);
    $new = clone $this;
    $new->headers->remove($header);
    $new->headerNames->remove($normalized);
    return $new;
  }

  public function getBody() {
    invariant(($this->stream is nonnull), "resource error");
    return $this->stream;
  }

  public function withBody(StreamInterface $body) {
    if ($body === $this->stream) {
      return $this;
    }
    $new = clone $this;
    $new->stream = $body;
    return $new;
  }

  private function validateAndTrimHeader(string $header, mixed $values): array<string> {
    if (1 !== \preg_match("@^[!#$%&'*+.^_`|~0-9A-Za-z-]+$@", $header)) {
      throw new \InvalidArgumentException('Header name must be an RFC 7230 compatible string.');
    }
    if (!\is_array($values)) {
      if ((!\is_numeric($values) && $values is string) || 1 !== \preg_match("@^[ \t\x21-\x7E\x80-\xFF]*$@", (string) $values)) {
        throw new \InvalidArgumentException('Header values must be RFC 7230 compatible strings.');
      }
      return [Str\trim((string) $values, " \t")];
    }
    
    if (!$values is nonnull || $values === '') {
      throw new \InvalidArgumentException('Header values must be a string or an array of strings, empty array given.');
    }
    $returnValues = [];
    foreach ($values as $v) {
      if ((!\is_numeric($v) && !$v is string) || 1 !== \preg_match("@^[ \t\x21-\x7E\x80-\xFF]*$@", (string) $v)) {
        throw new \InvalidArgumentException('Header values must be RFC 7230 compatible strings.');
      }
      $returnValues[] = Str\trim((string) $v, " \t");
    }
    return $returnValues;
  }
}
